# frozen_string_literal: true

module Api
  module V1
    class ArtifactsController < Api::V1::ApiController
      before_action :set_artifact, only: %i[show download_image download_images download_status]

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

      # POST /artifacts/:id/download_image
      # Synchronously downloads a single image size for the artifact
      #
      # @param size [String] Required - 'square' or 'wide'
      # @param force [Boolean] Optional - Force re-download even if exists
      def download_image
        size = params[:size]
        force = params[:force] == true || params[:force] == 'true'

        unless %w[square wide].include?(size)
          return render json: { error: "Invalid size. Must be 'square' or 'wide'" }, status: :bad_request
        end

        service = ArtifactImageDownloadService.new(@artifact, force: force, size: size, storage: :s3)
        result = service.download

        if result.success?
          render json: { success: true, images: result.images }
        else
          render json: { success: false, error: result.error }, status: :unprocessable_entity
        end
      end

      # POST /artifacts/:id/download_images
      # Asynchronously downloads all images for the artifact via background job
      #
      # @param options.force [Boolean] Optional - Force re-download even if exists
      # @param options.size [String] Optional - 'square', 'wide', or 'all' (default)
      def download_images
        options = params[:options] || {}
        force = options[:force] == true || options[:force] == 'true'
        size = options[:size] || 'all'

        DownloadArtifactImagesJob.perform_later(@artifact.id, force: force, size: size)

        render json: {
          status: 'queued',
          message: "Image download queued for artifact #{@artifact.granblue_id}",
          artifact_id: @artifact.id
        }, status: :accepted
      end

      # GET /artifacts/:id/download_status
      # Returns the current status of a background download job
      def download_status
        status = DownloadArtifactImagesJob.status(@artifact.id)
        render json: status
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
