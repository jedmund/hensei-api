# frozen_string_literal: true

module Api
  module V1
    # Receives the game's banner rates from script/fetch_gacha_rates.rb. It
    # authenticates with GACHA_RATES_TOKEN; without one, the endpoint is off.
    class GachaBannersController < ApiController
      skip_before_action :current_user
      before_action :authenticate_fetcher

      rescue_from GachaSimulation::ValidationError do |error|
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def create
        payload = JSON.parse(request.raw_post)
        result = GachaSimulation::BannerImport.call(payload)
        Rails.logger.info("gacha banner=#{result['game_id']} items=#{result['items']} unmatched=#{result['unmatched']}")
        render json: result, status: :created
      rescue JSON::ParserError
        render json: { error: 'Expected JSON' }, status: :bad_request
      end

      private

      def authenticate_fetcher
        expected = ENV['GACHA_RATES_TOKEN'].presence
        return head :not_found unless expected

        provided = request.authorization.to_s.delete_prefix('Bearer ')
        head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
      end
    end
  end
end
