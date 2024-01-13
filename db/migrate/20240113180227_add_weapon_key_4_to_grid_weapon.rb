class AddWeaponKey4ToGridWeapon < ActiveRecord::Migration[7.0]
  def change
    add_column :grid_weapons, :weapon_key4_id, :string
  end
end
