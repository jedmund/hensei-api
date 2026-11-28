# frozen_string_literal: true

module Api
  module V1
    # The game's past banners, for the spark maker
    class HistoricalBannersController < ApiController
      # GET /gacha/rate_ups?date=YYYY-MM-DD&pool=flash
      #
      # The banners running on a day (Japan time) in a pool, and the items
      # that were their rate-ups (BannerHistory::RateUps). Without a pool,
      # every main-draw banner that day; a pool the history doesn't have (the
      # Classic draws) has none.
      def rate_ups
        date = Date.iso8601(params.require(:date).to_s)
        result = BannerHistory::RateUps.new(date, params[:pool].presence).call

        expires_in 1.hour, public: true
        render json: { banners: result.banners, rate_ups: result.ids }
      rescue Date::Error
        render json: { error: 'date must be YYYY-MM-DD' }, status: :unprocessable_content
      end
    end
  end
end
