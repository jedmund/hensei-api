class AddGranblueIdToWeaponKeys < ActiveRecord::Migration[7.0]
  def change
    # This needs to be NOT NULL, but initially it will be nullable until we migrate data
    add_column :weapon_keys, :granblue_id, :integer, unique: true, null: true
  end
end
