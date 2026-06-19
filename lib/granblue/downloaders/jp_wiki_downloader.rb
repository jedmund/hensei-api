# frozen_string_literal: true

module Granblue
  module Downloaders
    # Fetches and caches raw HTML from the Japanese wiki (gbf-wiki.com) into
    # <record>.wiki_raw_jp. Works for any model with wiki_ja + wiki_raw_jp
    # (characters, summons). Once cached, parsing iterates offline with no
    # further network calls. The JP wiki has no API, so the batch backfill is
    # throttled to stay polite.
    class JpWikiDownloader
      DEFAULT_THROTTLE = 1.0 # seconds between requests

      # Backfill wiki_raw_jp for a model. Skips rows already cached unless force.
      def self.backfill(model:, limit: nil, throttle: DEFAULT_THROTTLE, force: false, debug: false)
        scope = model.where.not(wiki_ja: [nil, ''])
        scope = scope.where(wiki_raw_jp: [nil, '']) unless force
        scope = scope.limit(limit) if limit

        client = Granblue::Parsers::JpWiki.new(debug: debug)
        total = scope.count
        downloaded = 0
        errors = []

        scope.find_each.with_index do |record, index|
          new(record, client: client).download(force: force)
          downloaded += 1
          puts "#{index + 1}/#{total} #{label(record)}" if debug
          sleep(throttle) if throttle&.positive?
        rescue StandardError => e
          errors << "#{record.id}: #{e.message}"
          Rails.logger.error "[JP_WIKI] #{record.id}: #{e.message}"
        end

        { downloaded: downloaded, skipped: total - downloaded - errors.size, errors: errors }
      end

      def self.label(record)
        record.try(:name_en).presence || record.try(:granblue_id) || record.id
      end

      def initialize(record, client: nil)
        @record = record
        @client = client || Granblue::Parsers::JpWiki.new
      end

      # Fetches the JP wiki page and caches it. Returns the HTML, or nil when the
      # record has no JP title. No-op if already cached unless force.
      def download(force: false)
        return @record.wiki_raw_jp if @record.wiki_raw_jp.present? && !force
        return if @record.wiki_ja.blank?

        html = @client.fetch(@record.wiki_ja)
        @record.update!(wiki_raw_jp: html)
        html
      end
    end
  end
end
