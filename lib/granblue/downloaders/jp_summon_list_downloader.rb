# frozen_string_literal: true

module Granblue
  module Downloaders
    # Summons with no page of their own on gbf-wiki.com: every R and SR summon, and SSRs
    # whose page hasn't been written yet (the list marks them 【個別ページ】?). Their aura is
    # still listed on the rarity list pages (召喚石R, 召喚石SR, 召喚石SSR), one table row per
    # summon. This fetches those pages once each and stores a summon's row as its
    # wiki_raw_jp, so the aura parser has Japanese text to read.
    #
    # Rows are matched by granblue_id (the row's image file is named after it), not by name.
    # A summon's own page always wins: a stored page is never replaced by a row; a stored
    # row is replaced when the row changes.
    class JpSummonListDownloader
      PAGES = %w[召喚石R 召喚石SR 召喚石SSR].freeze

      # Marks a stored row, so a later run can tell it from a summon's own page.
      ROW_CLASS = 'gbf-wiki-list-row'

      # Returns a Granblue::SourceFetchSummary.
      def self.backfill(ids: nil, throttle: JpWikiDownloader::DEFAULT_THROTTLE, io: $stdout,
                        client: Granblue::Parsers::JpWiki.new)
        throttle = Granblue::WikiThrottle.clamp(throttle, warn: io.method(:puts))
        rows = {}
        PAGES.each_with_index do |page, index|
          Granblue::WikiThrottle.wait(throttle) if index.positive?
          rows_on(client.fetch(page), page).each { |id, row| rows[id] ||= row }
        end

        summary = Granblue::SourceFetchSummary.new('download_jp_summon_lists')
        scope = ids ? Summon.where(granblue_id: ids) : Summon.all
        scope.find_each do |summon|
          stored = summon.wiki_raw_jp
          next summary.skipped!('has its own page') if stored.present? && !row?(stored)

          row = rows[summon.granblue_id]
          next summary.skipped!('not on the list pages') unless row

          summon.update!(wiki_raw_jp: row, wiki_raw_jp_fetched_at: Time.current) if row != stored
          summary.fetched!(summon.granblue_id, before: stored, after: row)
        end
        summary.print(io)
        summary
      end

      # { granblue_id => stored row HTML } for one list page.
      def self.rows_on(html, page)
        html.to_s.scan(%r{<tr[^>]*>.*?</tr>}m).each_with_object({}) do |tr, rows|
          id = tr[/(\d{10})\.png/, 1]
          next unless id

          rows[id] ||= %(<div class="#{ROW_CLASS}" data-page="#{page}"><table>#{tr}</table></div>)
        end
      end

      def self.row?(html)
        html.to_s.start_with?(%(<div class="#{ROW_CLASS}"))
      end
    end
  end
end
