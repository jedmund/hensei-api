class AddAwakeningTypesToWeapons < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :awakening_types, :integer, array: true, default: []
  end
end
