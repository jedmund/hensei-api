module Api
  module V1
    class CollectionWeaponsController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_weapon_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch]
      before_action :set_collection_weapon_for_write, only: %i[update destroy]

      def index
        @collection_weapons = @target_user.collection_weapons
                                          .includes(:weapon, :awakening,
                                                   :weapon_key1, :weapon_key2,
                                                   :weapon_key3, :weapon_key4)

        @collection_weapons = @collection_weapons.by_weapon(params[:weapon_id]) if params[:weapon_id]
        @collection_weapons = @collection_weapons.by_element(params[:element]) if params[:element]
        @collection_weapons = @collection_weapons.by_rarity(params[:rarity]) if params[:rarity]

        @collection_weapons = @collection_weapons.paginate(page: params[:page], per_page: params[:limit] || 50)

        render json: Api::V1::CollectionWeaponBlueprint.render(
          @collection_weapons,
          root: :weapons,
          meta: pagination_meta(@collection_weapons)
        )
      end

      def show
        render json: Api::V1::CollectionWeaponBlueprint.render(
          @collection_weapon,
          view: :full
        )
      end

      def create
        @collection_weapon = current_user.collection_weapons.build(collection_weapon_params)

        if @collection_weapon.save
          render json: Api::V1::CollectionWeaponBlueprint.render(
            @collection_weapon,
            view: :full
          ), status: :created
        else
          render_validation_error_response(@collection_weapon)
        end
      end

      def update
        if @collection_weapon.update(collection_weapon_params)
          render json: Api::V1::CollectionWeaponBlueprint.render(
            @collection_weapon,
            view: :full
          )
        else
          render_validation_error_response(@collection_weapon)
        end
      end

      def destroy
        @collection_weapon.destroy
        head :no_content
      end

      # POST /collection/weapons/batch
      # Creates multiple collection weapons in a single request
      # Unlike characters, weapons can have duplicates (user can own multiple copies)
      def batch
        items = batch_weapon_params[:collection_weapons] || []
        created = []
        errors = []

        ActiveRecord::Base.transaction do
          items.each_with_index do |item_params, index|
            collection_weapon = current_user.collection_weapons.build(item_params)

            if collection_weapon.save
              created << collection_weapon
            else
              errors << {
                index: index,
                weapon_id: item_params[:weapon_id],
                error: collection_weapon.errors.full_messages.join(', ')
              }
            end
          end
        end

        status = errors.any? ? :multi_status : :created

        render json: Api::V1::CollectionWeaponBlueprint.render(
          created,
          root: :weapons,
          meta: { created: created.size, errors: errors }
        ), status: status
      end

      private

      def set_target_user
        @target_user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil? # Already handled by set_target_user
        unless @target_user.collection_viewable_by?(current_user)
          render json: { error: "You do not have permission to view this collection" }, status: :forbidden
        end
      end

      def set_collection_weapon_for_read
        @collection_weapon = @target_user.collection_weapons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('weapon', params[:id])
      end

      def set_collection_weapon_for_write
        @collection_weapon = current_user.collection_weapons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('weapon', params[:id])
      end

      def collection_weapon_params
        params.require(:collection_weapon).permit(
          :weapon_id, :uncap_level, :transcendence_step,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id, :weapon_key4_id,
          :awakening_id, :awakening_level,
          :ax_modifier1, :ax_strength1, :ax_modifier2, :ax_strength2,
          :element
        )
      end

      def batch_weapon_params
        params.permit(collection_weapons: [
          :weapon_id, :uncap_level, :transcendence_step,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id, :weapon_key4_id,
          :awakening_id, :awakening_level,
          :ax_modifier1, :ax_strength1, :ax_modifier2, :ax_strength2,
          :element
        ])
      end
    end
  end
end
