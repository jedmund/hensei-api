# frozen_string_literal: true

class AddWeaponStatModifierFks < ActiveRecord::Migration[8.0]
  def change
    # collection_weapons - add FK columns
    # Note: old ax_modifier1/ax_modifier2 integer columns still exist for data migration
    add_column :collection_weapons, :ax_modifier1_id, :bigint
    add_column :collection_weapons, :ax_modifier2_id, :bigint
    add_column :collection_weapons, :befoulment_modifier_id, :bigint
    add_column :collection_weapons, :befoulment_strength, :float
    add_column :collection_weapons, :exorcism_level, :integer, default: 0

    add_index :collection_weapons, :ax_modifier1_id
    add_index :collection_weapons, :ax_modifier2_id
    add_index :collection_weapons, :befoulment_modifier_id

    add_foreign_key :collection_weapons, :weapon_stat_modifiers, column: :ax_modifier1_id
    add_foreign_key :collection_weapons, :weapon_stat_modifiers, column: :ax_modifier2_id
    add_foreign_key :collection_weapons, :weapon_stat_modifiers, column: :befoulment_modifier_id

    # grid_weapons - same pattern
    add_column :grid_weapons, :ax_modifier1_id, :bigint
    add_column :grid_weapons, :ax_modifier2_id, :bigint
    add_column :grid_weapons, :befoulment_modifier_id, :bigint
    add_column :grid_weapons, :befoulment_strength, :float
    add_column :grid_weapons, :exorcism_level, :integer, default: 0

    add_index :grid_weapons, :ax_modifier1_id
    add_index :grid_weapons, :ax_modifier2_id
    add_index :grid_weapons, :befoulment_modifier_id

    add_foreign_key :grid_weapons, :weapon_stat_modifiers, column: :ax_modifier1_id
    add_foreign_key :grid_weapons, :weapon_stat_modifiers, column: :ax_modifier2_id
    add_foreign_key :grid_weapons, :weapon_stat_modifiers, column: :befoulment_modifier_id
  end
end
