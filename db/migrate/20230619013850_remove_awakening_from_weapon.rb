class RemoveAwakeningFromWeapon < ActiveRecord::Migration[7.0]
  def change
    remove_column :weapons, :awakening, :boolean
    remove_column :weapons, :awakening_types, :integer, array: true
  end
end
