# frozen_string_literal: true

module Api
  module V1
    class RaidsController < Api::V1::ApiController
      def all
        render json: RaidBlueprint.render(Raid.all)
      end
    end
  end
end
