# frozen_string_literal: true

module Api
  module V1
    module Concerns
      # Full-inventory sync for collection types whose game data carries a
      # per-copy game_id (weapons and summons): import can reconcile deletions,
      # preview_sync lists what a full sync would delete, and check_conflicts
      # finds imports that would collide with copies added by hand.
      #
      # Include it in a CollectionItemsController subclass.
      module CollectionInventorySync
        extend ActiveSupport::Concern

        # POST /collection/:type/preview_sync
        # Previews what a full sync would delete.
        #
        # @param data [Hash] Game data containing the item list
        # @return [JSON] List of items that would be deleted
        def preview_sync
          options = import_params
          return render_missing_data if options[:data].blank?

          service = item_type.import_service.new(current_user, options[:data], filter: options[:filter])
          items_to_delete = service.preview_deletions

          render json: {
            will_delete: items_to_delete.map { |item| deletion_preview(item) },
            count: items_to_delete.size
          }
        end

        # POST /collection/:type/check_conflicts
        # Finds imported items that would match an owned copy with no game_id.
        #
        # @param data [Hash] Game data containing the item list
        # @return [JSON] List of conflicting items
        def check_conflicts
          game_data = import_params[:data]
          return render_missing_data if game_data.blank?

          items = game_data.is_a?(Array) ? game_data : (game_data['list'] || [])
          render json: { conflicts: items.filter_map { |item| import_conflict(item) } }
        end

        private

        # @param update_existing [Boolean] Whether to update items already owned (default: false)
        # @param is_full_inventory [Boolean] Whether this is the user's complete inventory (default: false)
        # @param reconcile_deletions [Boolean] Whether to delete items not in the import (default: false)
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

        def import_options(options)
          super.merge(
            is_full_inventory: options[:is_full_inventory] == true,
            reconcile_deletions: options[:reconcile_deletions] == true,
            filter: options[:filter],
            conflict_resolutions: options[:conflict_resolutions]
          )
        end

        def import_summary(result)
          super.merge(reconciliation: result.reconciliation)
        end

        # Maps a game image id to the catalog's granblue_id.
        def resolve_granblue_id(granblue_id)
          granblue_id.to_s
        end

        def deletion_preview(item)
          catalog = item.public_send(item_type.type)
          {
            id: item.id,
            game_id: item.game_id,
            name: catalog&.name_en,
            granblue_id: catalog&.granblue_id,
            uncap_level: item.uncap_level,
            transcendence_step: item.transcendence_step
          }
        end

        def import_conflict(item)
          param = item['param'] || {}
          game_id = param['id']
          return if game_id.blank?

          image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
          granblue_id = image_id || (item['master'] || {})['id']
          return if granblue_id.blank?

          catalog = item_type.catalog.find_by(granblue_id: resolve_granblue_id(granblue_id))
          return unless catalog
          # Already matched by game_id: no conflict
          return if current_user_items.exists?(game_id: game_id.to_s)

          existing = current_user_items.find_by(foreign_key => catalog.id, game_id: nil)
          return unless existing

          {
            game_id: game_id.to_s,
            granblue_id: granblue_id.to_s,
            name: catalog.name_en,
            existing_id: existing.id,
            existing_uncap_level: existing.uncap_level
          }
        end
      end
    end
  end
end
