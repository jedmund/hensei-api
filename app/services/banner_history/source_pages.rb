# frozen_string_literal: true

module BannerHistory
  # gbf.wiki's Banner History, one page a year (Banner History/2014 onwards),
  # cached as shared wiki_raw sources keyed by page title. Fetching is its own
  # step, one page every few seconds; everything else reads the cache.
  class SourcePages
    FIRST_YEAR = 2014
    # User:Auryona's archive holds the years without a Banner History page
    ARCHIVE = 'User:Auryona'
    # Seconds between requests, to go easy on the wiki
    DELAY = 3

    def self.title(year)
      "Banner History/#{year}"
    end

    # The cached wikitext of each year that has a page, by year
    def self.cached(years = FIRST_YEAR..Time.current.year)
      years.filter_map do |year|
        body = Source.read(nil, :wiki_raw, key: title(year))
        [year, body] if body
      end.to_h
    end

    def self.cached_archive
      Source.read(nil, :wiki_raw, key: ARCHIVE)
    end

    def initialize(wiki: Granblue::Parsers::Wiki.new(store: nil), pause: ->(seconds) { sleep(seconds) })
      @wiki = wiki
      @pause = pause
    end

    # Fetches each year's page, then the archive, into the cache. A page that
    # doesn't exist is skipped. → { year or ARCHIVE => :changed | :unchanged | :missing }
    def fetch(years = FIRST_YEAR..Time.current.year)
      titles = years.index_with { |year| self.class.title(year) }.merge(ARCHIVE => ARCHIVE)
      titles.each_with_index.to_h do |(page, title), index|
        @pause.call(DELAY) if index.positive?
        body = @wiki.fetch_raw(title)
        next [page, :missing] if body.blank?

        result = Source.put(nil, :wiki_raw, body, key: title, fetched_at: Time.current)
        [page, result.changed? ? :changed : :unchanged]
      end
    end
  end
end
