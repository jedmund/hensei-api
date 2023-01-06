class ChangeAwakeningTypeDefaultValue < ActiveRecord::Migration[7.0]
  def change
    change_column :grid_characters, :awakening_type, :integer, null: false, default: 1
  end
end
