# frozen_string_literal: true

class FinalizeAxModifierColumns < ActiveRecord::Migration[8.0]
  def change
    # Remove old integer columns
    remove_column :collection_weapons, :ax_modifier1, :integer
    remove_column :collection_weapons, :ax_modifier2, :integer
    remove_column :grid_weapons, :ax_modifier1, :integer
    remove_column :grid_weapons, :ax_modifier2, :integer

    # Rename new FK columns to the original names
    rename_column :collection_weapons, :ax_modifier1_ref_id, :ax_modifier1_id
    rename_column :collection_weapons, :ax_modifier2_ref_id, :ax_modifier2_id
    rename_column :grid_weapons, :ax_modifier1_ref_id, :ax_modifier1_id
    rename_column :grid_weapons, :ax_modifier2_ref_id, :ax_modifier2_id
  end
end
