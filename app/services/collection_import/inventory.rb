# frozen_string_literal: true

module CollectionImport
  ##
  # Import flow for collection types the game tracks per copy (weapons,
  # summons, artifacts): each item carries the copy's game_id, which matches
  # it to the user's copy. Adds the full-inventory sync on top of Base:
  # reconciliation deletes copies missing from the import, preview_deletions
  # lists them, and conflict resolutions decide what happens to a copy the
  # user added by hand (no game_id) when the import has one like it.
  #
  # A type supplies game_id(item) and filter_scope(scope, filter), plus the
  # Base hooks.
  class Inventory < Base
    # @param options [Hash] besides update_existing: is_full_inventory,
    #   reconcile_deletions, filter (the game view's element_ids /
    #   proficiency_ids) and conflict_resolutions (game_id => 'import' or 'skip')
    def initialize(user, game_data, options = {})
      super
      @is_full_inventory = options[:is_full_inventory] || false
      @reconcile_deletions = options[:reconcile_deletions] || false
      @filter = CollectionImportFilter.from(options[:filter])
      @conflict_resolutions = options[:conflict_resolutions] || {}
      @processed_game_ids = []
    end

    ##
    # Previews what a full sync would delete: the user's copies with a game_id
    # the import doesn't have, inside the game filter. Changes nothing.
    #
    # @return [ActiveRecord::Relation, Array] the copies that would be deleted
    def preview_deletions
      items = extract_items
      return [] if items.empty?

      game_ids = items.filter_map { |item| game_id(item).presence&.to_s }
      return [] if game_ids.empty?

      filtered(collection.includes(config.type).where.not(game_id: nil).where.not(game_id: game_ids))
    end

    private

    def import_item(item)
      id = game_id(item)
      @processed_game_ids << id.to_s if id.present?

      catalog = find_catalog(item)
      return record_not_found(item) unless catalog

      existing = owned_copy(item)
      return save_item(item, catalog, existing) if existing || id.blank? || @conflict_resolutions.blank?

      resolve_conflict(item, catalog, @conflict_resolutions[id.to_s])
    end

    # A copy the import matched to nothing by game_id: 'import' adopts the
    # user's hand-added copy, 'skip' leaves it, anything else creates one.
    def resolve_conflict(item, catalog, resolution)
      case resolution
      when 'import'
        save_item(item, catalog, collection.find_by(config.foreign_key => catalog.id, game_id: nil), update: true)
      when 'skip'
        @skipped << skip_entry(item, catalog, 'Skipped by user')
      else
        save_item(item, catalog, nil)
      end
    end

    def owned_copy(item)
      collection.find_by(game_id: game_id(item).to_s)
    end

    def skip_entry(item, _catalog, reason)
      { game_id: game_id(item), reason: reason }
    end

    # Deletes the user's copies missing from a full inventory, inside the game
    # filter. Their grid items are orphaned by the copy's before_destroy.
    #
    # @return [Hash, nil] deleted count and the orphaned grid item ids
    def reconciliation
      return unless @reconcile_deletions && @is_full_inventory && @processed_game_ids.any?

      deleted = 0
      orphaned = []
      filtered(collection.where.not(game_id: nil).where.not(game_id: @processed_game_ids)).find_each do |copy|
        orphaned.concat(config.grid_model.where(config.grid_foreign_key => copy.id).pluck(:id))
        copy.destroy
        deleted += 1
      end

      { deleted: deleted, orphaned_grid_items: orphaned }
    end

    def filtered(scope)
      @filter.present? ? filter_scope(scope, @filter) : scope
    end
  end
end
