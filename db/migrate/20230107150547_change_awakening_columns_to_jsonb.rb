class ChangeAwakeningColumnsToJsonb < ActiveRecord::Migration[7.0]
  def change
    # Remove old columns
    remove_column :grid_characters, :awakening_type, :integer
    remove_column :grid_characters, :awakening_level, :integer

    # Add new column
    add_column :grid_characters, :awakening, :jsonb, default: { type: 1, level: 1 }
  end
end
