module Api
  module V1
    class CollectionController < ApiController
      before_action :set_target_user
      before_action :check_collection_access

      # GET /api/v1/users/:user_id/collection/counts
      # Returns total counts for all collection entity types
      def counts
        render json: {
          characters: @target_user.collection_characters.count,
          weapons: @target_user.collection_weapons.count,
          summons: @target_user.collection_summons.count,
          artifacts: @target_user.collection_artifacts.count
        }
      end

      # GET /api/v1/users/:user_id/collection/granblue_ids
      # Returns all granblue IDs in a user's collection (lightweight, for ownership checks)
      def granblue_ids
        render json: {
          weapons: @target_user.collection_weapons.joins(:weapon).pluck('DISTINCT weapons.granblue_id'),
          characters: @target_user.collection_characters.joins(:character).pluck('DISTINCT characters.granblue_id'),
          summons: @target_user.collection_summons.joins(:summon).pluck('DISTINCT summons.granblue_id')
        }
      end

      private

      def set_target_user
        @target_user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil?
        unless @target_user.collection_viewable_by?(current_user)
          render json: { error: "You do not have permission to view this collection" }, status: :forbidden
        end
      end
    end
  end
end
