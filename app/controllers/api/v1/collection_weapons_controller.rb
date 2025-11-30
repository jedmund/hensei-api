module Api
  module V1
    class CollectionWeaponsController < ApiController
      before_action :restrict_access
      before_action :set_collection_weapon, only: [:show, :update, :destroy]

      def index
        @collection_weapons = current_user.collection_weapons
                                          .includes(:weapon, :awakening,
                                                   :weapon_key1, :weapon_key2,
                                                   :weapon_key3, :weapon_key4)

        @collection_weapons = @collection_weapons.by_weapon(params[:weapon_id]) if params[:weapon_id]
        @collection_weapons = @collection_weapons.by_element(params[:element]) if params[:element]
        @collection_weapons = @collection_weapons.by_rarity(params[:rarity]) if params[:rarity]

        @collection_weapons = @collection_weapons.paginate(page: params[:page], per_page: params[:limit] || 50)

        render json: Api::V1::CollectionWeaponBlueprint.render(
          @collection_weapons,
          root: :collection_weapons,
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

      private

      def set_collection_weapon
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
    end
  end
end