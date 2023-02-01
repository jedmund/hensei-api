# frozen_string_literal: true

module Api
  module V1
    class SummonsController < Api::V1::ApiController
      before_action :set

      def show
        render json: SummonBlueprint.render(@summon)
      end

      private

      def set
        @summon = Summon.where(granblue_id: params[:id]).first
      end
    end
  end
end
