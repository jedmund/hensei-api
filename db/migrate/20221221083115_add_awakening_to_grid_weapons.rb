class AddAwakeningToGridWeapons < ActiveRecord::Migration[6.1]
  def change
    add_column :grid_weapons, :awakening_type, :integer, null: true
    add_column :grid_weapons, :awakening_level, :integer, null: false, default: 1
  end
end
