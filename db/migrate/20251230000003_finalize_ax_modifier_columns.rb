# frozen_string_literal: true

class FinalizeAxModifierColumns < ActiveRecord::Migration[8.0]
  def change
    # Remove old integer columns (data has been migrated to ax_modifier1_id/ax_modifier2_id FKs)
    remove_column :collection_weapons, :ax_modifier1, :integer
    remove_column :collection_weapons, :ax_modifier2, :integer
    remove_column :grid_weapons, :ax_modifier1, :integer
    remove_column :grid_weapons, :ax_modifier2, :integer
  end
end
