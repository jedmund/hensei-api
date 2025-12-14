# frozen_string_literal: true

module Api
  module V1
    class CollectionArtifactsController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_artifact_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch import]
      before_action :set_collection_artifact_for_write, only: %i[update destroy]

      def index
        @collection_artifacts = @target_user.collection_artifacts.includes(:artifact)

        @collection_artifacts = @collection_artifacts.where(artifact_id: params[:artifact_id]) if params[:artifact_id]
        @collection_artifacts = @collection_artifacts.where(element: params[:element]) if params[:element]
        @collection_artifacts = @collection_artifacts.joins(:artifact).where(artifacts: { rarity: params[:rarity] }) if params[:rarity]

        @collection_artifacts = @collection_artifacts.paginate(page: params[:page], per_page: params[:limit] || 50)

        render json: Api::V1::CollectionArtifactBlueprint.render(
          @collection_artifacts,
          root: :artifacts,
          meta: pagination_meta(@collection_artifacts)
        )
      end

      def show
        render json: Api::V1::CollectionArtifactBlueprint.render(
          @collection_artifact,
          view: :full
        )
      end

      def create
        @collection_artifact = current_user.collection_artifacts.build(collection_artifact_params)

        if @collection_artifact.save
          render json: Api::V1::CollectionArtifactBlueprint.render(
            @collection_artifact,
            view: :full
          ), status: :created
        else
          render_validation_error_response(@collection_artifact)
        end
      end

      def update
        if @collection_artifact.update(collection_artifact_params)
          render json: Api::V1::CollectionArtifactBlueprint.render(
            @collection_artifact,
            view: :full
          )
        else
          render_validation_error_response(@collection_artifact)
        end
      end

      def destroy
        @collection_artifact.destroy
        head :no_content
      end

      # POST /collection/artifacts/batch
      # Creates multiple collection artifacts in a single request
      def batch
        items = batch_artifact_params[:collection_artifacts] || []
        created = []
        errors = []

        ActiveRecord::Base.transaction do
          items.each_with_index do |item_params, index|
            collection_artifact = current_user.collection_artifacts.build(item_params)

            if collection_artifact.save
              created << collection_artifact
            else
              errors << {
                index: index,
                artifact_id: item_params[:artifact_id],
                error: collection_artifact.errors.full_messages.join(', ')
              }
            end
          end
        end

        status = errors.any? ? :multi_status : :created

        render json: Api::V1::CollectionArtifactBlueprint.render(
          created,
          root: :artifacts,
          meta: { created: created.size, errors: errors }
        ), status: status
      end

      # POST /collection/artifacts/import
      # Imports artifacts from game JSON data
      #
      # @param data [Hash] Game data containing artifact list
      # @param update_existing [Boolean] Whether to update existing artifacts (default: false)
      def import
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = ArtifactImportService.new(
          current_user,
          game_data,
          update_existing: import_params[:update_existing] == true
        )

        result = service.import

        status = result.success? ? :created : :multi_status

        render json: {
          success: result.success?,
          created: result.created&.size || 0,
          updated: result.updated&.size || 0,
          skipped: result.skipped&.size || 0,
          errors: result.errors || []
        }, status: status
      end

      private

      def set_target_user
        @target_user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil?

        return if @target_user.collection_viewable_by?(current_user)

        render json: { error: 'You do not have permission to view this collection' }, status: :forbidden
      end

      def set_collection_artifact_for_read
        @collection_artifact = @target_user.collection_artifacts.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('artifact', params[:id])
      end

      def set_collection_artifact_for_write
        @collection_artifact = current_user.collection_artifacts.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('artifact', params[:id])
      end

      def collection_artifact_params
        params.require(:collection_artifact).permit(
          :artifact_id, :element, :proficiency, :level, :nickname, :reroll_slot,
          skill1: %i[modifier strength level],
          skill2: %i[modifier strength level],
          skill3: %i[modifier strength level],
          skill4: %i[modifier strength level]
        )
      end

      def batch_artifact_params
        params.permit(collection_artifacts: [
          :artifact_id, :element, :proficiency, :level, :nickname, :reroll_slot,
          { skill1: %i[modifier strength level] },
          { skill2: %i[modifier strength level] },
          { skill3: %i[modifier strength level] },
          { skill4: %i[modifier strength level] }
        ])
      end

      def import_params
        {
          update_existing: params[:update_existing],
          data: params[:data]&.to_unsafe_h
        }
      end
    end
  end
end
