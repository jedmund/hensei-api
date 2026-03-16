class AddNumWeaponKeysToWeaponSeries < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_series, :num_weapon_keys, :integer
  end
end
