# frozen_string_literal: true

module Api
  module V1
    class ArtifactSkillsController < Api::V1::ApiController
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
    end
  end
end
