# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillVersionsController < Api::V1::ApiController
      before_action :ensure_editor_role

      # PATCH /weapon_skill_versions/:id — classification only; labels live on
      # the shared Skill row (skills#update).
      def update
        version = WeaponSkillVersion.find(params[:id])
        version.update!(version_params)
        render json: WeaponSkillVersionBlueprint.render_as_hash(version).merge(id: version.id,
                                                                               skill_id: version.skill_id)
      end

      private

      def version_params
        params.require(:weapon_skill_version)
              .permit(:skill_modifier, :skill_series, :skill_size, :main_hand_only, :mc_only,
                      :scales_with_skill_level, :multiplier_frame, :min_uncap, :transcendence_stage,
                      :skill_id)
      end
    end
  end
end
