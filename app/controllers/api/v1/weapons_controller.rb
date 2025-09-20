# frozen_string_literal: true

module Api
  module V1
    class WeaponsController < Api::V1::ApiController
      include IdResolvable

      before_action :set

      def show
        render json: WeaponBlueprint.render(@weapon, view: :full)
      end

      private

      def set
        @weapon = find_by_any_id(Weapon, params[:id])
        render_not_found_response('weapon') unless @weapon
      end
    end
  end
end
