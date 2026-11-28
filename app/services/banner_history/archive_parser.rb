# frozen_string_literal: true

module BannerHistory
  # Reads User:Auryona's banner archive, which holds the years gbf.wiki's
  # Banner History pages don't (2015–2019 and 2021–2022), into the same
  # banners Parser makes. Each banner is a table row (bold title, then the
  # start date and time), followed by labelled rows of linked items:
  #
  #   | '''[https://… Premium Gala]'''
  #   | 2022-12-31<br/>(12:00)
  #   |- class="expand-child" …
  #   | colspan="5" | {{tt|Rate Up SSR Char|0.300% per featured character}}: [[Makura]], [[Michael]]
  #
  # Items link to character and summon pages, so character lists resolve
  # through Character.
  module ArchiveParser
    # The archive's list labels → Parser's field names
    FIELDS = {
      'Rate Up SSR Char' => 'rateup_char', 'Sparkable & Rate Up SSR Char' => 'rateup_char',
      'Rate Up SSR/SR/R Char' => 'rateup_char', 'Sparkable & Rate Up SSR SR/R Char' => 'rateup_char',
      'Sparkable SSR Char' => 'sparkable_char', 'Sparkable SSRChar' => 'sparkable_char',
      'Rate Up SR/R Char' => 'rateup_sr_char', 'Sparkable & Rate Up SR/R Char' => 'rateup_sr_char',
      'Sparkable SR/R Char' => 'sparkable_sr_char',
      'Rate Up Summons' => 'rateup_sum', 'Sparkable & Rate Up Summons' => 'rateup_sum',
      'Sparkable Summons' => 'sparkable_sum', 'Sparkable SSR Summon' => 'sparkable_sum',
      'Rate Up Weapons' => 'rateup_wep', 'Sparkable & Rate Up Weapons' => 'rateup_wep',
      'Sparkable Weapons' => 'sparkable_wep',
      'Sparkable Zodiacs' => 'zodiacs',
      'Sparkable Grands' => 'grands', 'Available Grands' => 'grands'
    }.freeze

    TITLE_ROW = %r{^\|[^\n]*?'''(?<title>.+?)'''\s*\n\|\s*(?<date>\d{4}-\d{2}-\d{2})(?:<br\s*/?>\s*\((?<time>\d{1,2}:\d{2})\))?}
    LIST_ROW = /^\|\s*colspan="\d+"\s*\|\s*(?:\{\{tt\|(?<tt>[^|}]+)(?:\|(?<rate>[^}]*))?\}\}|(?<label>[A-Za-z][A-Za-z &\/]*?))\s*:\s*(?<items>.*)$/

    module_function

    def parse(wikitext)
      text = wikitext.to_s
      starts = text.enum_for(:scan, TITLE_ROW).map { Regexp.last_match }
      starts.each_with_index.map do |match, index|
        stop = starts[index + 1]&.begin(0) || text.length
        banner(match, text[match.end(0)...stop])
      end
    end

    def banner(match, rows)
      title = plain(match[:title])
      lists = Hash.new { |hash, key| hash[key] = [] }
      rates = {}
      rows.scan(LIST_ROW) do
        found = Regexp.last_match
        field = FIELDS[(found[:tt] || found[:label]).strip]
        next unless field

        lists[field].concat(links(found[:items]))
        rates[field] = plain(found[:rate]) if found[:rate]
      end
      {
        type: type(title), start_date: Parser.date(match[:date]), start_time: match[:time],
        end_date: nil, end_time: nil, name: title, news_url: nil,
        lists: lists.transform_values(&:uniq), rates: rates
      }
    end

    # Galas by their names; everything else is an ordinary Premium draw
    def type(title)
      case title
      when /\AFlash Gala/i then 'flash'
      when /\APremium Gala/i then 'premium'
      when /\ALegend Festival/i then 'legend'
      else 'archive'
      end
    end

    # The page each [[Page|label]] link points at
    def links(text)
      text.to_s.scan(/\[\[([^|\]]+)(?:\|[^\]]*)?\]\]/).map { |(page)| Granblue::WikiTitle.normalize(page) }
    end

    # Markup stripped to its text
    def plain(text)
      text.to_s.gsub(%r{\[https?://\S+\s+([^\]]+)\]}, '\1').gsub(/\[\[(?:[^|\]]*\|)?([^\]]+)\]\]/, '\1')
          .gsub(%r{<br\s*/?>}, ' ').gsub(/<[^>]+>/, '').gsub(/\s+/, ' ').strip
    end
  end
end
