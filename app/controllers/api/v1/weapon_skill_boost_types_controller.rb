# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillBoostTypesController < Api::V1::ApiController
      # GET /weapon_skill_boost_types
      def index
        @boost_types = WeaponSkillBoostType.all
        @boost_types = @boost_types.where(category: params[:category]) if params[:category].present?

        render json: WeaponSkillBoostTypeBlueprint.render(@boost_types, root: :weapon_skill_boost_types)
      end

      # GET /weapon_skill_boost_types/:id
      def show
        @boost_type = WeaponSkillBoostType.find(params[:id])
        render json: WeaponSkillBoostTypeBlueprint.render(@boost_type)
      end
    end
  end
end
