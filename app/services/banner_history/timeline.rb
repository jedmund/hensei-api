# frozen_string_literal: true

module BannerHistory
  # When each banner ran, from the dates on the wiki. The main draw has no
  # gaps: a banner runs until the minute before the next one starts. Galas
  # start at 12:00 JST from the 2026-09-16 Flash Gala on and 19:00 before
  # that, except the 12-31 Premium Gala, which always starts at 12:00; other
  # banners start at 19:00. A start time on the wiki wins. Collab banners run
  # alongside the main draw, with their own start and end.
  class Timeline
    ZONE = 'Asia/Tokyo'
    # legend is 2014's Legend Festival, the Premium Gala's forerunner
    GALA_TYPES = %w[premium flash premium_allstar flash_allstar legend].freeze
    COLLAB_TYPES = %w[collab].freeze
    NOON_GALAS_FROM = Date.new(2026, 9, 16)
    # Longer than any banner runs: a bigger jump between starts is a stretch
    # the wiki doesn't cover (it has no pages for 2015–2019 or 2021–2022)
    LONGEST_BANNER = 40.days

    # The spark maker's pool for each kind of banner (features/spark/pools.ts):
    # the Premium Gala is the Legend Festival, every other draw is Premium
    POOLS = { 'premium' => 'legend', 'premium_allstar' => 'legend', 'legend' => 'legend', 'flash' => 'flash',
              'flash_allstar' => 'flash', 'collab' => 'collab' }.freeze

    Entry = Struct.new(:banner, :starts_at, :ends_at, keyword_init: true) do
      def type = banner[:type]
      def gala? = GALA_TYPES.include?(type)
      def collab? = COLLAB_TYPES.include?(type)
      def pool = POOLS.fetch(type, 'premium')
    end

    attr_reader :entries, :problems

    def initialize(banners)
      @problems = []
      dated, undated = banners.partition { |banner| banner[:start_date] }
      undated.each { |banner| @problems << "No start date: #{banner[:type]} #{banner[:name]}".strip }
      entries = dated.map { |banner| Entry.new(banner: banner, starts_at: starts_at(banner)) }
      main, collabs = entries.partition { |entry| !entry.collab? }
      @entries = chain(main.sort_by(&:starts_at)) + collabs.map { |entry| collab_end(entry) }.sort_by(&:starts_at)
    end

    def main = entries.reject(&:collab?)
    def collabs = entries.select(&:collab?)

    private

    def starts_at(banner)
      zone.parse("#{banner[:start_date]} #{banner[:start_time] || default_time(banner)}")
    end

    def default_time(banner)
      date = banner[:start_date]
      return '12:00' if banner[:type] == 'premium' && date.month == 12 && date.day == 31
      return '12:00' if GALA_TYPES.include?(banner[:type]) && date >= NOON_GALAS_FROM

      '19:00'
    end

    # Each banner ends the minute before the next starts; the latest is still
    # running, and one before a stretch the wiki doesn't cover has no known end
    def chain(sorted)
      sorted.each_cons(2) do |current, following|
        @problems << "Same start: #{current.type} and #{following.type} at #{current.starts_at.iso8601}" if following.starts_at <= current.starts_at
        if following.starts_at - current.starts_at > LONGEST_BANNER
          @problems << "Gap in coverage: #{current.starts_at.to_date} → #{following.starts_at.to_date}"
          next
        end
        current.ends_at = following.starts_at - 1.minute
      end
      sorted
    end

    def collab_end(entry)
      banner = entry.banner
      if banner[:end_date]
        entry.ends_at = zone.parse("#{banner[:end_date]} #{banner[:end_time] || '18:59'}")
      else
        @problems << "Collab without an end: #{banner[:name]} (#{banner[:start_date]})"
      end
      entry
    end

    def zone
      ActiveSupport::TimeZone[ZONE]
    end
  end
end
