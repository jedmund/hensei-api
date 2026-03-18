# frozen_string_literal: true

module Api
  module V1
    class WeaponStatModifiersController < Api::V1::ApiController
      # GET /weapon_stat_modifiers
      def index
        @modifiers = WeaponStatModifier.all
        @modifiers = @modifiers.where(category: params[:category]) if params[:category].present?

        render json: WeaponStatModifierBlueprint.render(@modifiers)
      end

      # GET /weapon_stat_modifiers/:id
      def show
        @modifier = WeaponStatModifier.find(params[:id])
        render json: WeaponStatModifierBlueprint.render(@modifier)
      end
    end
  end
end
