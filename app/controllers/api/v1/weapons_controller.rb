# frozen_string_literal: true

module Api
  module V1
    class WeaponsController < Api::V1::ApiController
      before_action :set

      def show
        render json: WeaponBlueprint.render(@weapon)
      end

      private

      def set
        @weapon = Weapon.where(granblue_id: params[:id]).first
      end
    end
  end
end
