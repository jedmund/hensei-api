# frozen_string_literal: true

module Api
  module V1
    class ArtifactsController < Api::V1::ApiController
      before_action :set_artifact, only: [:show]

      # GET /artifacts
      def index
        @artifacts = Artifact.all
        @artifacts = @artifacts.where(rarity: params[:rarity]) if params[:rarity].present?
        @artifacts = @artifacts.where(proficiency: params[:proficiency]) if params[:proficiency].present?

        render json: ArtifactBlueprint.render(@artifacts, root: :artifacts)
      end

      # GET /artifacts/:id
      def show
        render json: ArtifactBlueprint.render(@artifact)
      end

      # POST /artifacts/grade
      # Grades artifact skills without persisting. Accepts skill data and returns grade/recommendation.
      #
      # @param artifact_id [String] Optional - ID of base artifact (for quirk detection)
      # @param skill1 [Hash] Skill data with modifier, strength, level
      # @param skill2 [Hash] Skill data with modifier, strength, level
      # @param skill3 [Hash] Skill data with modifier, strength, level
      # @param skill4 [Hash] Skill data with modifier, strength, level
      def grade
        artifact_data = build_gradeable_artifact
        grader = ArtifactGrader.new(artifact_data)

        render json: { grade: grader.grade }
      end

      private

      def set_artifact
        @artifact = Artifact.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found_response('artifact')
      end

      def build_gradeable_artifact
        base_artifact = params[:artifact_id].present? ? Artifact.find_by(id: params[:artifact_id]) : nil

        # Build a simple struct that responds to what ArtifactGrader needs
        OpenStruct.new(
          skill1: grade_params[:skill1] || {},
          skill2: grade_params[:skill2] || {},
          skill3: grade_params[:skill3] || {},
          skill4: grade_params[:skill4] || {},
          artifact: base_artifact || OpenStruct.new(quirk?: false)
        )
      end

      def grade_params
        params.permit(
          :artifact_id,
          skill1: %i[modifier strength level],
          skill2: %i[modifier strength level],
          skill3: %i[modifier strength level],
          skill4: %i[modifier strength level]
        )
      end
    end
  end
end
