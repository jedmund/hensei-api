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
          weapons: @target_user.collection_weapons.joins(:weapon).distinct.pluck('weapons.granblue_id'),
          characters: @target_user.collection_characters.joins(:character).distinct.pluck('characters.granblue_id'),
          summons: @target_user.collection_summons.joins(:summon).distinct.pluck('summons.granblue_id')
        }
      end

      # POST /api/v1/users/:user_id/collection/item_count
      # Returns collection items matching a specific granblue_id, with count
      def item_count
        type = params[:type]
        granblue_id = params[:granblue_id]

        unless %w[character weapon summon].include?(type)
          return render json: { error: "Invalid type" }, status: :unprocessable_entity
        end

        unless granblue_id.present?
          return render json: { error: "granblue_id is required" }, status: :unprocessable_entity
        end

        case type
        when 'character'
          items = @target_user.collection_characters
            .joins(:character)
            .where(characters: { granblue_id: granblue_id })
          render json: {
            count: items.count,
            items: Api::V1::CollectionCharacterBlueprint.render_as_hash(items)
          }
        when 'weapon'
          items = @target_user.collection_weapons
            .joins(:weapon)
            .where(weapons: { granblue_id: granblue_id })
          render json: {
            count: items.count,
            items: Api::V1::CollectionWeaponBlueprint.render_as_hash(items)
          }
        when 'summon'
          items = @target_user.collection_summons
            .joins(:summon)
            .where(summons: { granblue_id: granblue_id })
          render json: {
            count: items.count,
            items: Api::V1::CollectionSummonBlueprint.render_as_hash(items)
          }
        end
      end

      # GET /api/v1/users/:user_id/collection/game_ids
      # Returns game instance IDs for ownership checks (per-instance matching)
      # Characters use granblue_ids since they have no game_id column
      def game_ids
        render json: {
          weapons: @target_user.collection_weapons.where.not(game_id: nil).pluck(:game_id),
          summons: @target_user.collection_summons.where.not(game_id: nil).pluck(:game_id),
          artifacts: @target_user.collection_artifacts.where.not(game_id: nil).pluck(:game_id),
          characters: @target_user.collection_characters.joins(:character).distinct.pluck('characters.granblue_id')
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
