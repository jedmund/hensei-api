# frozen_string_literal: true

require 'cgi'

module Granblue
  module Extractors
    # Japanese aura text from a summon's stored gbf-wiki.com HTML (wiki_raw_jp): either the
    # summon's own page (its 加護 rows) or a row copied from a rarity list page
    # (Granblue::Downloaders::JpSummonListDownloader).
    #
    # The wiki writes every uncap tier in one sentence and marks what each tier adds by color:
    # "全属性攻撃力が80<orange>(90)</orange><purple>(100)</purple>%UP<purple>/主人公の…</purple>".
    # Each page states its colors in a legend (この色は★3上限解放時, …, この色は限界超越後);
    # pages and list rows without one use the usual families in order of appearance. #text
    # renders one tier: a tier's "(…)" replaces the value before it, and text added at a
    # higher tier is left out. Text added after transcendence is never rendered: the wiki
    # doesn't say at which stage it comes.
    #
    # Pure: no writes, no network.
    class SummonAuraJpExtractor
      # Color families, by the tier they usually mark.
      FAMILIES = {
        orange: %w[#ff6600 orange red #ff0000 #f00],
        purple: %w[#9932cc purple #800080],
        blue: %w[#1e90ff blue #0000ff #3366ff #00f],
        transcendence: %w[#333399]
      }.freeze
      FAMILY_OF = FAMILIES.flat_map { |family, colors| colors.map { |c| [c, family] } }.to_h.freeze
      LEGEND_TIERS = { '★3' => 3, '★4' => 4, '★5' => 5, '限界超越' => :transcendence }.freeze
      # The wiki's usual colors, for pages and list rows without a legend.
      DEFAULT_TIERS = { orange: 3, purple: 4, blue: 5, transcendence: :transcendence }.freeze
      LABELS = { 'main' => /【?メイン(?:装備時|加護)】?\s*[：:]?/, 'sub' => /【?サブ(?:装備時|加護)】?\s*[：:]?/ }.freeze

      Token = Struct.new(:text, :tier)
      Aura = Struct.new(:name, :slots, keyword_init: true) # slots: { 'main' => [Token], 'sub' => [Token] }

      # → Aura, or nil when the HTML holds no aura.
      def extract(html)
        html = html.to_s
        section = aura_section(html)
        return unless section

        cells, name = section
        tiers = tiers_for(html, cells)
        tokens = tokenize(cells, tiers)
        slots = split_slots(tokens)
        slots.empty? ? nil : Aura.new(name: name, slots: slots)
      end

      # The rendered text of one slot at an uncap level; nil when the slot is absent or empty.
      def text(aura, slot, uncap_level)
        tokens = aura&.slots&.dig(slot)
        return unless tokens

        out = +''
        tokens.each do |token|
          next unless included?(token.tier, uncap_level)

          if token.tier.is_a?(Integer) && (variant = token.text[/\A\s*[(（](.+?)[)）]\s*\z/, 1])
            replace_value(out, variant)
          else
            out << token.text
          end
        end
        tidy(out).presence
      end

      private

      def included?(tier, uncap_level)
        tier.is_a?(Integer) && tier <= uncap_level
      end

      # "攻撃力が80" + "(90)" → "攻撃力が90"; a variant that doesn't follow a value is appended.
      def replace_value(out, variant)
        if out =~ /[\d,.]+\s*[%％]?\s*\z/ && variant =~ /\A[\d,.]+\s*[%％]?\z/
          out.sub!(/[\d,.]+\s*[%％]?\s*\z/, variant)
        else
          out << variant
        end
      end

      # → [cells HTML, aura name]. A list row: the cell after the cooldown (…ターン). A page:
      # the rows from the 加護 header to the flavor text, without the header and name cells.
      def aura_section(html)
        if html.include?('gbf-wiki-list-row')
          cells = html.scan(%r{<td[^>]*>(.*?)</td>}m).flatten
          cooldown = cells.index { |c| plain(c).match?(/ターン/) }
          return cooldown && cells[cooldown + 1] ? [cells[cooldown + 1], nil] : nil
        end

        header = html.index(%r{<th[^>]*>\s*加護\s*</th>})
        return unless header

        start = html.rindex('<tr', header)
        flavor = html.index('フレーバーテキスト', header)
        finish = flavor ? html.rindex('<tr', flavor) : html.index('</table>', header)
        rows = html[start...finish].to_s
        cells = rows.scan(%r{<td[^>]*>(.*?)</td>}m).flatten
        name = nil
        name = plain(cells.shift) if rows.match?(%r{<th[^>]*>\s*名称\s*</th>}) && cells.size > 1
        [cells.join('<br>'), name]
      end

      # { color family => tier } from the page's legend, else DEFAULT_TIERS.
      def tiers_for(html, _cells)
        legend = html.scan(/color:\s*([#\w]+)[^>]*>\s*(?:<strong>)?\s*この色は(★\d|限界超越)/).to_h do |color, tier|
          [FAMILY_OF[color.downcase] || color.downcase, LEGEND_TIERS[tier]]
        end
        legend.any? ? legend : DEFAULT_TIERS
      end

      # → [Token] with each piece of text and the tier it belongs to (0 = every tier).
      def tokenize(html, tiers)
        tokens = []
        stack = [0] # the tier of the enclosing colored span
        html.scan(/<[^>]+>|[^<]+/).each do |piece|
          if piece.start_with?('<')
            tag(piece, tiers, stack, tokens)
          else
            text = CGI.unescapeHTML(piece)
            tokens << Token.new(text, stack.last) unless text.empty?
          end
        end
        tokens
      end

      # A span opens or closes a tier (a span without a tier color keeps the enclosing one);
      # a block tag is a line break; other tags are dropped.
      def tag(piece, tiers, stack, tokens)
        name = piece[%r{\A</?(\w+)}, 1].to_s.downcase
        if name != 'span'
          tokens << Token.new("\n", 0) if %w[br p div tr].include?(name)
        elsif piece.start_with?('</')
          stack.pop if stack.size > 1
        else
          color = piece[/color:\s*([#\w]+)/, 1]&.downcase
          stack.push((color && tiers[FAMILY_OF[color] || color]) || stack.last)
        end
      end

      # { 'main' => [Token], 'sub' => [Token] } split at the メイン/サブ labels; no labels → main.
      def split_slots(tokens)
        joined = tokens.map(&:text).join
        marks = LABELS.flat_map do |slot, re|
          joined.to_enum(:scan, re).map { [Regexp.last_match.begin(0), Regexp.last_match.end(0), slot] }
        end.sort
        return { 'main' => tokens } if marks.empty? && plain_text?(tokens)
        return {} if marks.empty?

        marks.each_with_index.to_h do |(_, label_end, slot), i|
          stop = marks[i + 1]&.first || joined.size
          [slot, slice(tokens, label_end, stop)]
        end
      end

      def plain_text?(tokens)
        tokens.any? { |t| t.text.strip.present? }
      end

      # The tokens covering joined[from...to], cut at the edges.
      def slice(tokens, from, to)
        pos = 0
        tokens.each_with_object([]) do |token, out|
          first = pos
          pos += token.text.size
          next if pos <= from || first >= to

          out << Token.new(token.text[[from - first, 0].max...(to - first)], token.tier)
        end
      end

      def plain(html)
        CGI.unescapeHTML(html.to_s.gsub(/<[^>]+>/, ' ')).gsub(/\s+/, ' ').strip
      end

      # The wiki breaks lines both between clauses and to wrap long ones. Keep a break only
      # before a note (◆ ※ ・) or a bracketed aside; join the rest, as Japanese needs no space.
      def tidy(text)
        lines = text.lines.map { |l| l.gsub(/[ \t　]+/, ' ').strip }.reject(&:empty?)
        lines.each_with_index.sum('') do |line, i|
          i.zero? || line.match?(/\A[◆※・(（【]/) ? "#{"\n" unless i.zero?}#{line}" : line
        end.gsub(%r{\s*/\s*}, '/').gsub(%r{/+\z}, '').gsub(%r{/\n}, "\n").strip
      end
    end
  end
end
