class AddSlugToWeaponKeys < ActiveRecord::Migration[6.1]
  def change
    add_column :weapon_keys, :slug, :string
  end
end
