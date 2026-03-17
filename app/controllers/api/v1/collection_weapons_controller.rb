module Api
  module V1
    class CollectionWeaponsController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_weapon_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch batch_destroy import preview_sync check_conflicts]
      before_action :set_collection_weapon_for_write, only: %i[update destroy]

      def index
        @collection_weapons = @target_user.collection_weapons
                                          .includes({ weapon: [:weapon_series, :weapon_series_variant] }, :awakening,
                                                   :weapon_key1, :weapon_key2,
                                                   :weapon_key3, :weapon_key4,
                                                   :ax_modifier1, :ax_modifier2,
                                                   :befoulment_modifier)

        # Apply filters (array_param splits comma-separated values for OR logic)
        @collection_weapons = @collection_weapons.by_weapon(params[:weapon_id]) if params[:weapon_id]
        @collection_weapons = @collection_weapons.by_element(array_param(:element)) if params[:element]
        @collection_weapons = @collection_weapons.by_rarity(array_param(:rarity)) if params[:rarity]
        @collection_weapons = @collection_weapons.by_proficiency(array_param(:proficiency)) if params[:proficiency]
        @collection_weapons = @collection_weapons.by_series(array_param(:series)) if params[:series]
        @collection_weapons = @collection_weapons.by_name(params[:search]) if params[:search].present?

        @collection_weapons = @collection_weapons.sorted_by(params[:sort])

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

      # DELETE /collection/weapons/batch_destroy
      # Deletes multiple collection weapons in a single request
      def batch_destroy
        ids = batch_destroy_params[:ids] || []
        deleted_count = current_user.collection_weapons.where(id: ids).destroy_all.count

        render json: {
          meta: { deleted: deleted_count }
        }, status: :ok
      end

      # POST /collection/weapons/import
      # Imports weapons from game JSON data
      #
      # @param data [Hash] Game data containing weapon list
      # @param update_existing [Boolean] Whether to update existing weapons (default: false)
      # @param is_full_inventory [Boolean] Whether this represents the user's complete inventory (default: false)
      # @param reconcile_deletions [Boolean] Whether to delete items not in the import (default: false)
      def import
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = WeaponImportService.new(
          current_user,
          game_data,
          update_existing: import_params[:update_existing] == true,
          is_full_inventory: import_params[:is_full_inventory] == true,
          reconcile_deletions: import_params[:reconcile_deletions] == true,
          filter: import_params[:filter],
          conflict_resolutions: import_params[:conflict_resolutions]
        )

        result = service.import

        status = result.success? ? :created : :multi_status

        render json: {
          success: result.success?,
          created: result.created.size,
          updated: result.updated.size,
          skipped: result.skipped.size,
          errors: result.errors,
          reconciliation: result.reconciliation
        }, status: status
      end

      # POST /collection/weapons/preview_sync
      # Previews what would be deleted in a full sync operation
      #
      # @param data [Hash] Game data containing weapon list
      # @return [JSON] List of items that would be deleted
      def preview_sync
        game_data = import_params[:data]
        filter = import_params[:filter]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = WeaponImportService.new(current_user, game_data, filter: filter)
        items_to_delete = service.preview_deletions

        render json: {
          will_delete: items_to_delete.map do |cw|
            {
              id: cw.id,
              game_id: cw.game_id,
              name: cw.weapon&.name_en,
              granblue_id: cw.weapon&.granblue_id,
              uncap_level: cw.uncap_level,
              transcendence_step: cw.transcendence_step
            }
          end,
          count: items_to_delete.size
        }
      end

      # POST /collection/weapons/check_conflicts
      # Checks for items that would conflict with existing null-game_id records
      #
      # @param data [Hash] Game data containing weapon list
      # @return [JSON] List of conflicting items
      def check_conflicts
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        items = game_data.is_a?(Array) ? game_data : (game_data['list'] || [])
        conflicts = []

        items.each do |item|
          param = item['param'] || {}
          master = item['master'] || {}

          game_id = param['id']
          next unless game_id.present?

          image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
          granblue_id = image_id || master['id']
          next unless granblue_id.present?

          weapon = Weapon.find_by(granblue_id: granblue_id.to_s)
          next unless weapon

          # Already matched by game_id — no conflict
          next if current_user.collection_weapons.exists?(game_id: game_id.to_s)

          # Check for existing record with null game_id for the same weapon
          existing = current_user.collection_weapons.find_by(weapon_id: weapon.id, game_id: nil)
          next unless existing

          conflicts << {
            game_id: game_id.to_s,
            granblue_id: granblue_id.to_s,
            name: weapon.name_en,
            existing_id: existing.id,
            existing_uncap_level: existing.uncap_level
          }
        end

        render json: { conflicts: conflicts }
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
          :ax_modifier1_id, :ax_strength1, :ax_modifier2_id, :ax_strength2,
          :befoulment_modifier_id, :befoulment_strength, :exorcism_level,
          :element
        )
      end

      def batch_weapon_params
        params.permit(collection_weapons: [
          :weapon_id, :uncap_level, :transcendence_step,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id, :weapon_key4_id,
          :awakening_id, :awakening_level,
          :ax_modifier1_id, :ax_strength1, :ax_modifier2_id, :ax_strength2,
          :befoulment_modifier_id, :befoulment_strength, :exorcism_level,
          :element
        ])
      end

      def import_params
        {
          update_existing: params[:update_existing],
          is_full_inventory: params[:is_full_inventory],
          reconcile_deletions: params[:reconcile_deletions],
          data: params[:data]&.to_unsafe_h,
          filter: params[:filter]&.to_unsafe_h,
          conflict_resolutions: params[:conflict_resolutions]&.to_unsafe_h
        }
      end

      def batch_destroy_params
        params.permit(ids: [])
      end

      def array_param(key)
        params[key]&.to_s&.split(',')
      end
    end
  end
end
