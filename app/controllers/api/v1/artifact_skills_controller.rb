# frozen_string_literal: true

module Api
  module V1
    class ArtifactSkillsController < Api::V1::ApiController
      before_action :set_artifact_skill, only: %w[show update]
      before_action :ensure_editor_role, only: %w[update]

      # GET /artifact_skills
      def index
        @skills = ArtifactSkill.all
        @skills = @skills.where(skill_group: params[:group]) if params[:group].present?
        @skills = @skills.where(polarity: params[:polarity]) if params[:polarity].present?

        render json: ArtifactSkillBlueprint.render(@skills, root: :artifact_skills)
      end

      # GET /artifact_skills/for_slot/:slot
      # Returns skills valid for a specific slot (1-4)
      def for_slot
        slot = params[:slot].to_i

        unless (1..4).cover?(slot)
          return render json: { error: 'Slot must be between 1 and 4' }, status: :unprocessable_entity
        end

        @skills = ArtifactSkill.for_slot(slot)
        render json: ArtifactSkillBlueprint.render(@skills, root: :artifact_skills)
      end

      # GET /artifact_skills/:id
      def show
        render json: ArtifactSkillBlueprint.render(@skill)
      end

      # PATCH/PUT /artifact_skills/:id
      def update
        if @skill.update(artifact_skill_params)
          ArtifactSkill.clear_cache!
          render json: ArtifactSkillBlueprint.render(@skill)
        else
          render_validation_error_response(@skill)
        end
      end

      private

      def set_artifact_skill
        @skill = ArtifactSkill.find(params[:id])
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def artifact_skill_params
        params.permit(
          :skill_group, :modifier,
          :name_en, :name_jp,
          :game_name_en, :game_name_jp,
          :suffix_en, :suffix_jp,
          :growth, :polarity,
          base_values: []
        )
      end
    end
  end
end
