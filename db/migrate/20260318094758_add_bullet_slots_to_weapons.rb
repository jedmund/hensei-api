class AddBulletSlotsToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :bullet_slots, :integer, array: true, default: [], null: false
  end
end
