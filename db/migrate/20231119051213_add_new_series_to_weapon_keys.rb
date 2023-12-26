class AddNewSeriesToWeaponKeys < ActiveRecord::Migration[7.0]
  def change
    add_column :weapon_keys, :new_series, :integer, null: false, default: [], array: true
  end
end
