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

      private

      def set_artifact
        @artifact = Artifact.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found_response('artifact')
      end
    end
  end
end
