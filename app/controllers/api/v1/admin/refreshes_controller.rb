# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Curators refresh what Home and the gacha simulator show without waiting
      # for their caches (GBF-279). Every action answers with the current
      # status.
      class RefreshesController < Api::V1::ApiController
        before_action :ensure_curator_role

        def show
          render json: status_payload
        end

        # Home rebuilds on its next request instead of when its 5-minute cache ends
        def home
          HomeFeed.expire
          Rails.logger.info("refresh home by user=#{current_user.id}")
          render json: status_payload
        end

        # Reloads the gacha catalogue in every process and asks the fetcher to
        # read the game's banner again on its next run
        def gacha
          GachaSimulation::Refresh.request!
          Rails.logger.info("refresh gacha by user=#{current_user.id}")
          render json: status_payload
        end

        private

        def status_payload
          banner = GachaBanner.current
          {
            home: { cache_seconds: HomeController::CACHE_TTL.to_i },
            gacha: {
              banner: banner && {
                game_id: banner.game_id, name: banner.name, starts_at: banner.starts_at,
                ends_at: banner.ends_at, fetched_at: banner.fetched_at, live: banner.live?
              },
              refetch_requested_at: GachaSimulation::Refresh.refetch_requested_at
            }
          }
        end
      end
    end
  end
end
