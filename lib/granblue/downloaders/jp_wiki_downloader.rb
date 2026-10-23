# frozen_string_literal: true

module Granblue
  module Downloaders
    # Fetches and caches raw HTML from the Japanese wiki (gbf-wiki.com) into
    # <record>.wiki_raw_jp (its wiki_raw_jp source, div#body only). Works for any model with name_jp + wiki_raw_jp
    # (characters, summons, weapons). Once cached, parsing iterates offline
    # with no further network calls. The JP wiki has no API, so the batch
    # backfill is throttled to stay polite.
    class JpWikiDownloader
      DEFAULT_THROTTLE = Granblue::WikiThrottle::MIN_DELAY # seconds between requests

      RARITY_SUFFIX = {
        1 => '(R)',
        2 => '(SR)',
        3 => '(SSR)'
      }.freeze

      # Backfill wiki_raw_jp for a model. Skips rows already cached unless force.
      # Uses wiki_ja (decoded if still percent-encoded); falls back to name_jp +
      # rarity suffix when wiki_ja is blank.
      #
      #   ids:     granblue_ids, taken as given (a row with no resolvable title is skipped)
      #   missing: only rows with a blank wiki_raw_jp (force then changes nothing:
      #            a blank row is always fetched)
      #   force:   refetch rows that already have wiki_raw_jp; without ids/missing,
      #            only those rows
      #
      # Returns { downloaded:, skipped:, errors:, summary: } (a Granblue::SourceFetchSummary).
      def self.backfill(model:, limit: nil, throttle: DEFAULT_THROTTLE, force: false, debug: false, # rubocop:disable Metrics/ParameterLists
                        ids: nil, missing: false)
        throttle = Granblue::WikiThrottle.clamp(throttle, warn: method(:puts))
        scope = backfill_scope(model, ids: ids, missing: missing, force: force)
        scope = scope.limit(limit) if limit

        total = scope.count
        puts "Downloading JP wiki pages for #{total} #{model.name.downcase}s" \
             "#{' (missing only)' if missing || !force}...\n\n"

        client = Granblue::Parsers::JpWiki.new(debug: debug)
        summary = Granblue::SourceFetchSummary.new('download_jp_wiki')
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        scope.find_each.with_index do |record, index|
          progress = index + 1
          title = resolve_title(record)
          downloader = new(record, client: client, jp_title: title)
          requested = downloader.request?(force: force)
          unless requested
            summary.skipped!(title.blank? ? 'no title' : 'has wiki_raw_jp')
            next
          end

          before = record.wiki_raw_jp
          html = downloader.download(force: force)
          summary.fetched!(record.granblue_id, before: before, after: html)
          print_progress(progress, total, label(record), before == html ? 'unchanged' : 'changed', start_time)
        rescue StandardError => e
          summary.error!(record.granblue_id, "#{e.message} (#{title})", label: label(record))
          print_progress(progress, total, label(record), "ERR: #{e.message}", start_time)
        ensure
          Granblue::WikiThrottle.wait(throttle) if requested # only after a real request to gbf-wiki.com
        end

        print_summary(summary, start_time)
        { downloaded: summary.fetched, skipped: summary.skipped, errors: summary.errors, summary: summary }
      end

      def self.backfill_scope(model, ids:, missing:, force:)
        scope = if ids then model.where(granblue_id: ids)
                elsif force && !missing then with_page(model)
                else eligible_scope(model)
                end
        missing ? scope.where.not(id: with_page(model).select(:id)) : scope
      end

      # Rows with a stored page (a `sources` row, D35).
      def self.with_page(model)
        model.with_source(:wiki_raw_jp)
      end

      # What's stored for a page: only div#body (Granblue::JpWikiPage).
      def self.storable(_record, html)
        Granblue::JpWikiPage.trim(html)
      end

      # Records eligible for JP wiki download: have a clean wiki_ja, or have
      # name_jp (so we can construct the title ourselves).
      def self.eligible_scope(model)
        clean_wiki_ja = model.where.not(wiki_ja: [nil, '']).where.not('wiki_ja LIKE ?', '%{%')
        with_name_jp = model.where(wiki_ja: [nil, '']).where.not(name_jp: [nil, ''])
        model.where(id: clean_wiki_ja).or(model.where(id: with_name_jp))
      end

      # Resolve the JP wiki page title for a record.
      #   - wiki_ja: decoded to the plain title if it's still percent-encoded (UTF-8 or
      #     EUC-JP); raises Granblue::JpWikiTitle::InvalidTitle when it can't be decoded,
      #     so the backfill reports the row instead of fetching a garbled title
      #   - Otherwise: construct from name_jp + rarity suffix
      # Weapons get a 武器/ prefix on gbf-wiki.com unless the title already names a path
      # (武器/…, or a series page like 武器概要/…); characters/summons do not.
      def self.resolve_title(record)
        wiki_ja = Granblue::JpWikiTitle.decode!(record.wiki_ja.to_s)

        title = if wiki_ja.present?
                  wiki_ja
                else
                  name_jp = record.name_jp.to_s
                  return nil if name_jp.blank?

                  suffix = RARITY_SUFFIX[record.rarity] || ''
                  "#{name_jp} #{suffix}".strip
                end

        record.is_a?(Weapon) && !title.include?('/') ? "武器/#{title}" : title
      end

      def self.print_progress(current, total, name, status, start_time)
        pct = format('%5.1f%%', current.to_f / total * 100)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        eta = current > 1 ? format_eta((elapsed / current) * (total - current)) : '?'
        error = status.start_with?('ERR')
        marker = error ? 'ERR' : 'OK'
        suffix = error ? " (#{status})" : " #{status}"
        line = "[#{current}/#{total}] #{pct}  [#{marker}] #{name}#{suffix}"
        line += "  elapsed: #{format_eta(elapsed)}  eta: #{eta}"
        puts line
      end

      def self.print_summary(summary, start_time)
        elapsed = format_eta(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time)

        puts "\n#{'=' * 60}"
        puts "Done in #{elapsed}"
        summary.print($stdout)
      end

      def self.format_eta(seconds)
        return '<1s' if seconds < 1

        s = seconds.to_i
        return "#{s}s" if s < 60

        m, s = s.divmod(60)
        return "#{m}m#{s}s" if m < 60

        h, m = m.divmod(60)
        "#{h}h#{m}m"
      end

      def self.label(record)
        record.try(:name_en).presence || record.try(:granblue_id) || record.id
      end

      def initialize(record, client: nil, jp_title: nil)
        @record = record
        @client = client || Granblue::Parsers::JpWiki.new
        @jp_title = jp_title || self.class.resolve_title(record)
      end

      # True when download will fetch the page (not cached, or force, and a title).
      def request?(force: false)
        (@record.wiki_raw_jp.blank? || force) && @jp_title.present?
      end

      # Fetches the JP wiki page and caches it. Returns the HTML, or nil when
      # no title could be resolved. No-op if already cached unless force.
      def download(force: false)
        return @record.wiki_raw_jp if @record.wiki_raw_jp.present? && !force
        return if @jp_title.blank?

        html = self.class.storable(@record, @client.fetch(@jp_title))
        @record.update!(wiki_raw_jp: html, wiki_raw_jp_fetched_at: Time.current)
        html
      end

      # Fetches the JP wiki page without storing it (the editor's refresh preview stores it
      # later, if they apply). → the HTML as it would be stored, or nil when no title could
      # be resolved.
      # before_request is called before the request to gbf-wiki.com (the caller's spacing).
      def fetch(before_request: nil)
        return if @jp_title.blank?

        before_request&.call
        self.class.storable(@record, @client.fetch(@jp_title))
      end
    end
  end
end
