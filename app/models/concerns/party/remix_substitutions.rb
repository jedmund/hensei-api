# frozen_string_literal: true

##
# Recreates a source party's substitutions on its remix. Amoeba copies the
# grid items but not the Substitution rows that join them, so the remix
# flow sets `_source_party_for_remap` and the after_create hook rebuilds them.
module Party::RemixSubstitutions
  extend ActiveSupport::Concern

  included do
    attr_writer :_source_party_for_remap

    after_create :create_remapped_substitutions
  end

  private

  ##
  # Recreates substitution join records after an amoeba remix.
  #
  # Maps old grid item IDs to new ones by matching on item FK + position + is_substitute,
  # then creates Substitution records pointing to the new grid items.
  #
  # @return [void]
  def create_remapped_substitutions
    return unless @_source_party_for_remap

    remap_substitutions_for('GridCharacter', @_source_party_for_remap.all_characters, all_characters, :character_id)
    remap_substitutions_for('GridWeapon', @_source_party_for_remap.all_weapons, all_weapons, :weapon_id)
    remap_substitutions_for('GridSummon', @_source_party_for_remap.all_summons, all_summons, :summon_id)
  end

  def remap_substitutions_for(grid_type, old_items, new_items, item_fk)
    new_index = new_items.index_by { |ni| [ni.send(item_fk), ni.position, ni.is_substitute] }
    old_by_id = old_items.index_by(&:id)

    old_items.each do |old_item|
      old_item.substitutions.each do |sub|
        new_grid = new_index[[old_item.send(item_fk), old_item.position, old_item.is_substitute]]
        old_sub_grid = old_by_id[sub.substitute_grid_id]

        unless old_sub_grid
          Rails.logger.warn(
            "[Party#remap_substitutions_for] skip: substitute grid #{sub.substitute_grid_id} " \
            "missing from source party=#{@_source_party_for_remap&.id} type=#{grid_type}"
          )
          next
        end

        new_sub_grid = new_index[[old_sub_grid.send(item_fk), old_sub_grid.position, old_sub_grid.is_substitute]]

        unless new_grid && new_sub_grid
          Rails.logger.warn(
            "[Party#remap_substitutions_for] skip: no new mapping for sub=#{sub.id} " \
            "source=#{@_source_party_for_remap&.id} target=#{id} type=#{grid_type} " \
            "missing=#{new_grid.nil? ? 'new_grid' : 'new_sub_grid'}"
          )
          next
        end

        Substitution.create!(
          grid_type: grid_type,
          grid_id: new_grid.id,
          substitute_grid_type: grid_type,
          substitute_grid_id: new_sub_grid.id,
          position: sub.position
        )
      end
    end
  end
end
