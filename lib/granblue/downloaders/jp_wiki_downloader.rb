# frozen_string_literal: true

module Granblue
  module Downloaders
    # Fetches and caches raw HTML from the Japanese wiki (gbf-wiki.com) into
    # <record>.wiki_raw_jp. Works for any model with name_jp + wiki_raw_jp
    # (characters, summons, weapons). Once cached, parsing iterates offline
    # with no further network calls. The JP wiki has no API, so the batch
    # backfill is throttled to stay polite.
    class JpWikiDownloader
      DEFAULT_THROTTLE = 1.0 # seconds between requests

      RARITY_SUFFIX = {
        1 => '(R)',
        2 => '(SR)',
        3 => '(SSR)'
      }.freeze

      # Backfill wiki_raw_jp for a model. Skips rows already cached unless force.
      # Uses wiki_ja when it's clean Japanese; falls back to name_jp + rarity
      # suffix when wiki_ja is blank or a legacy percent-encoded path.
      def self.backfill(model:, limit: nil, throttle: DEFAULT_THROTTLE, force: false, debug: false)
        scope = model.where.not(wiki_raw_jp: [nil, '']) if force
        scope ||= eligible_scope(model)
        scope = scope.limit(limit) if limit

        total = scope.count
        puts "Downloading JP wiki pages for #{total} #{model.name.downcase}s" \
             "#{' (missing only)' unless force}...\n\n"

        client = Granblue::Parsers::JpWiki.new(debug: debug)
        downloaded = 0
        errored = []
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        scope.find_each.with_index do |record, index|
          progress = index + 1
          title = resolve_title(record)
          new(record, client: client, jp_title: title).download(force: force)
          downloaded += 1
          print_progress(progress, total, label(record), 'OK', start_time)
        rescue StandardError => e
          errored << { name: label(record), title: title, error: e.message }
          print_progress(progress, total, label(record), "ERR: #{e.message}", start_time)
        ensure
          sleep(throttle) if throttle&.positive?
        end

        print_summary(downloaded, errored, total, start_time)
        { downloaded: downloaded, skipped: total - downloaded - errored.size, errors: errored }
      end

      # Records eligible for JP wiki download: have a clean wiki_ja, or have
      # name_jp (so we can construct the title ourselves).
      def self.eligible_scope(model)
        clean_wiki_ja = model.where.not(wiki_ja: [nil, '']).where.not('wiki_ja LIKE ?', '%{%')
        with_name_jp = model.where(wiki_ja: [nil, '']).where.not(name_jp: [nil, ''])
        model.where(id: clean_wiki_ja).or(model.where(id: with_name_jp))
      end

      # Resolve the JP wiki page title for a record.
      #   - Percent-encoded wiki_ja: pass through (JpWiki decodes it)
      #   - Clean wiki_ja (plain Japanese): use as-is
      #   - Otherwise: construct from name_jp + rarity suffix
      # Weapons get a 武器/ prefix on gbf-wiki.com; characters/summons do not.
      def self.resolve_title(record)
        wiki_ja = record.wiki_ja.to_s
        return wiki_ja if wiki_ja.present? && wiki_ja.match?(/%[0-9A-Fa-f]{2}/)

        title = if wiki_ja.present?
                  wiki_ja
                else
                  name_jp = record.name_jp.to_s
                  return nil if name_jp.blank?

                  suffix = RARITY_SUFFIX[record.rarity] || ''
                  "#{name_jp} #{suffix}".strip
                end

        record.is_a?(Weapon) && !title.start_with?('武器/') ? "武器/#{title}" : title
      end

      def self.print_progress(current, total, name, status, start_time)
        pct = format('%5.1f%%', (current.to_f / total * 100))
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        eta = current > 1 ? format_eta((elapsed / current) * (total - current)) : '?'
        marker = status == 'OK' ? 'OK' : 'ERR'
        suffix = status == 'OK' ? '' : " (#{status})"
        line = "[#{current}/#{total}] #{pct}  [#{marker}] #{name}#{suffix}"
        line += "  elapsed: #{format_eta(elapsed)}  eta: #{eta}"
        puts line
      end

      def self.print_summary(downloaded, errored, total, start_time)
        elapsed = format_eta(Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time)

        puts "\n#{'=' * 60}"
        puts "Done in #{elapsed}"
        puts "  Downloaded: #{downloaded}"
        puts "  Errors:     #{errored.size}"
        puts "  Skipped:    #{total - downloaded - errored.size}"

        return if errored.empty?

        puts "\nErrors:"
        errored.each { |e| puts "  #{e[:name]} (#{e[:title]}) — #{e[:error]}" }
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

      # Fetches the JP wiki page and caches it. Returns the HTML, or nil when
      # no title could be resolved. No-op if already cached unless force.
      def download(force: false)
        return @record.wiki_raw_jp if @record.wiki_raw_jp.present? && !force
        return if @jp_title.blank?

        html = @client.fetch(@jp_title)
        @record.update!(wiki_raw_jp: html)
        html
      end
    end
  end
end
