class RemoveAwakeningFromWeapon < ActiveRecord::Migration[7.0]
  def change
    remove_column :weapons, :awakening, :boolean
  end
end
