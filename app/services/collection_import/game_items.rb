# frozen_string_literal: true

module CollectionImport
  ##
  # Item handling for the game's weapon and summon lists, whose items are
  # { param: the player's copy, master: the catalog item }. Include it in an
  # Inventory subclass.
  module GameItems
    ##
    # Dry run: the diff that import with update_existing would apply to each
    # copy the user owns. Items the user doesn't own are left out.
    #
    # @return [Array<Hash>] one entry per changed copy: { game_id:, granblue_id:, changes: [...] }
    def preview_updates
      extract_items.filter_map do |item|
        id = game_id(item)
        next if id.blank? || granblue_id(item).blank?

        catalog = find_catalog(item)
        existing = catalog && collection.find_by(game_id: id.to_s)
        next unless existing

        existing.assign_attributes(build_attrs(item, catalog))
        next if existing.changes.empty?

        { game_id: id.to_s, granblue_id: catalog.granblue_id, changes: ChangeFormatter.format(existing.changes) }
      end
    end

    private

    def game_params(item)
      item['param'] || {}
    end

    def game_id(item)
      game_params(item)['id']
    end

    # The catalog id: param.image_id without the suffix some items carry
    # ("_03" on Dark Opus weapons, "_04" on transcended summons), else master.id.
    def granblue_id(item)
      param = game_params(item)
      image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
      image_id || (item['master'] || {})['id']
    end

    # The copy's game_id and catalog id, for error entries.
    def item_ref(item, catalog = nil)
      { game_id: game_id(item), granblue_id: catalog ? catalog.granblue_id : granblue_id(item) }
    end

    def game_id_attr(item)
      game_id(item).presence&.to_s
    end
  end
end
