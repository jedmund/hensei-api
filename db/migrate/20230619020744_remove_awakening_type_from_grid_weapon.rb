class RemoveAwakeningTypeFromGridWeapon < ActiveRecord::Migration[7.0]
  def change
    remove_column :grid_weapons, :awakening_type, :integer
  end
end
