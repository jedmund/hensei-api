# frozen_string_literal: true

module Api
  module V1
    class SummonsController < Api::V1::ApiController
      include IdResolvable

      before_action :set

      def show
        render json: SummonBlueprint.render(@summon, view: :full)
      end

      private

      def set
        @summon = find_by_any_id(Summon, params[:id])
        render_not_found_response('summon') unless @summon
      end
    end
  end
end
