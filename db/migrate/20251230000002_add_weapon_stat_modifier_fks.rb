# frozen_string_literal: true

class AddWeaponStatModifierFks < ActiveRecord::Migration[8.0]
  def change
    # collection_weapons - add FK columns
    add_reference :collection_weapons, :ax_modifier1_ref,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_reference :collection_weapons, :ax_modifier2_ref,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_reference :collection_weapons, :befoulment_modifier,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_column :collection_weapons, :befoulment_strength, :float
    add_column :collection_weapons, :exorcism_level, :integer, default: 0

    # grid_weapons - same pattern
    add_reference :grid_weapons, :ax_modifier1_ref,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_reference :grid_weapons, :ax_modifier2_ref,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_reference :grid_weapons, :befoulment_modifier,
                  foreign_key: { to_table: :weapon_stat_modifiers }
    add_column :grid_weapons, :befoulment_strength, :float
    add_column :grid_weapons, :exorcism_level, :integer, default: 0
  end
end
