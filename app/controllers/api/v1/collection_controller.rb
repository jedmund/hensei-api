module Api
  module V1
    class CollectionController < ApiController
      before_action :set_user
      before_action :check_collection_access

      # GET /api/v1/users/:user_id/collection
      # GET /api/v1/users/:user_id/collection?type=weapons
      def show
        collection = case params[:type]
        when 'characters'
          {
            characters: Api::V1::CollectionCharacterBlueprint.render_as_hash(
              @user.collection_characters.includes(:character, :awakening),
              view: :full
            )
          }
        when 'weapons'
          {
            weapons: Api::V1::CollectionWeaponBlueprint.render_as_hash(
              @user.collection_weapons.includes(:weapon, :awakening, :weapon_key1,
                                               :weapon_key2, :weapon_key3, :weapon_key4),
              view: :full
            )
          }
        when 'summons'
          {
            summons: Api::V1::CollectionSummonBlueprint.render_as_hash(
              @user.collection_summons.includes(:summon),
              view: :full
            )
          }
        when 'job_accessories'
          {
            job_accessories: Api::V1::CollectionJobAccessoryBlueprint.render_as_hash(
              @user.collection_job_accessories.includes(job_accessory: :job)
            )
          }
        else
          # Return complete collection
          {
            characters: Api::V1::CollectionCharacterBlueprint.render_as_hash(
              @user.collection_characters.includes(:character, :awakening),
              view: :full
            ),
            weapons: Api::V1::CollectionWeaponBlueprint.render_as_hash(
              @user.collection_weapons.includes(:weapon, :awakening, :weapon_key1,
                                               :weapon_key2, :weapon_key3, :weapon_key4),
              view: :full
            ),
            summons: Api::V1::CollectionSummonBlueprint.render_as_hash(
              @user.collection_summons.includes(:summon),
              view: :full
            ),
            job_accessories: Api::V1::CollectionJobAccessoryBlueprint.render_as_hash(
              @user.collection_job_accessories.includes(job_accessory: :job)
            )
          }
        end

        render json: collection
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def check_collection_access
        unless @user.collection_viewable_by?(current_user)
          render json: { error: "You do not have permission to view this collection" }, status: :forbidden
        end
      end
    end
  end
end