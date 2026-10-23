# frozen_string_literal: true

module Api
  module V1
    class SkillsController < Api::V1::ApiController
      before_action :ensure_editor_role

      # PATCH /skills/:id — labels only. The skill is shared by every version
      # pointing at it; shared_by_count lets the UI warn before broad edits.
      def update
        skill = Skill.find(params[:id])
        skill.update!(params.require(:skill).permit(:name_en, :name_jp, :description_en, :description_jp))
        render json: SkillBlueprint.render_as_hash(skill)
                                   .merge(shared_by_count: skill.weapon_skill_versions.count)
      end
    end
  end
end
