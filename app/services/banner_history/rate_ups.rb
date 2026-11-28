# frozen_string_literal: true

module BannerHistory
  # The items that were rate-ups on the banners running on a day (Japan time)
  # in a pool, for the spark maker. A banner the game fetcher stored
  # (GachaBanner, from October 2026) speaks for itself with the game's own
  # rate-up flags; any other uses what the wiki lists (HistoricalBanner).
  #
  # A stored game banner takes its pool from the wiki banner that starts with
  # it. Until the wiki has it, a 6% banner counts for either gala pool and a
  # 3% one for Premium.
  class RateUps
    Result = Struct.new(:banners, :ids, keyword_init: true)

    # A wiki banner and a game banner starting this close together are one banner
    SAME_BANNER = 2.hours
    GALA_POOLS = %w[flash legend].freeze
    # Sparks hold SSRs, so a game banner's SR and R rate-ups are left out
    SSR = 3

    def initialize(date, pool)
      @day = ActiveSupport::TimeZone[HistoricalBanner::ZONE].parse(date.to_s).all_day
      @pool = pool
    end

    def call
      ids = Set.new
      covered = Set.new
      banners = game_banners.filter_map do |game, history|
        covered << history.id if history
        ids.merge(game.rates.where(tab: 1, rate_up: true, rarity: SSR).pluck(:reward_id))
        summary(history, game)
      end
      history_banners.reject { |banner| covered.include?(banner.id) }.each do |banner|
        ids.merge(banner.items.where(role: HistoricalBanner::RATE_UP_ROLES).pluck(:granblue_id))
        banners << summary(banner, nil)
      end
      Result.new(banners: banners.sort_by { |banner| banner[:starts_at] }, ids: ids.to_a.sort)
    end

    private

    # [[GachaBanner, its HistoricalBanner or nil]] running that day in the pool
    def game_banners
      GachaBanner.where(starts_at: ..@day.end).where(ends_at: @day.begin..).order(:starts_at).filter_map do |game|
        history = HistoricalBanner.where.not(pool: 'collab')
                                  .find_by(starts_at: (game.starts_at - SAME_BANNER)..(game.starts_at + SAME_BANNER))
        [game, history] if pool_matches?(history ? [history.pool] : unmatched_pools(game))
      end
    end

    def history_banners
      banners = HistoricalBanner.on_day(@day.begin.to_date).includes(:items).order(:starts_at)
      return banners.where.not(pool: 'collab') if @pool.nil?
      return banners.where(pool: @pool) if HistoricalBanner::POOLS.include?(@pool)

      banners.none
    end

    def unmatched_pools(game)
      BigDecimal(game.rarity_rates.dig('1', '3').to_s) >= BigDecimal('0.05') ? GALA_POOLS : %w[premium]
    end

    def pool_matches?(pools)
      @pool.nil? ? pools.exclude?('collab') : pools.include?(@pool)
    end

    def summary(history, game)
      {
        kind: history&.kind || 'game', pool: history&.pool, name: history&.name || game&.name,
        starts_at: (game&.starts_at || history.starts_at).iso8601,
        ends_at: (game ? game.ends_at : history.ends_at)&.iso8601,
        source: game ? 'game' : 'wiki'
      }
    end
  end
end
