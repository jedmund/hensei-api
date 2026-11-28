# frozen_string_literal: true

module Api
  module V1
    # The game's past banners (gbf.wiki's Banner History), for the spark maker
    class HistoricalBannersController < ApiController
      # GET /gacha/rate_ups?date=YYYY-MM-DD&pool=flash
      #
      # The banners running on a day (Japan time) in a pool, and the items
      # that counted as their rate-ups. Without a pool, every main-draw banner
      # that day; a pool the history doesn't have (the Classic draws) has none.
      def rate_ups
        date = Date.iso8601(params.require(:date).to_s)
        banners = in_pool(HistoricalBanner.on_day(date), params[:pool].presence).order(:starts_at)
        ids = HistoricalBannerItem.where(historical_banner_id: banners.select(:id), role: HistoricalBanner::RATE_UP_ROLES)
                                  .distinct.pluck(:granblue_id).sort

        expires_in 1.hour, public: true
        render json: { banners: banners.map { |banner| summary(banner) }, rate_ups: ids }
      rescue Date::Error
        render json: { error: 'date must be YYYY-MM-DD' }, status: :unprocessable_content
      end

      private

      def in_pool(banners, pool)
        return banners.where.not(pool: 'collab') if pool.nil?
        return banners.where(pool: pool) if HistoricalBanner::POOLS.include?(pool)

        banners.none
      end

      def summary(banner)
        { kind: banner.kind, pool: banner.pool, name: banner.name,
          starts_at: banner.starts_at.iso8601, ends_at: banner.ends_at&.iso8601 }
      end
    end
  end
end
