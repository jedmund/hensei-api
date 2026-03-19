class CreateGridWeaponBullets < ActiveRecord::Migration[8.0]
  def change
    create_table :grid_weapon_bullets, id: :uuid do |t|
      t.uuid :grid_weapon_id, null: false
      t.uuid :bullet_id, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :grid_weapon_bullets, :grid_weapon_id
    add_index :grid_weapon_bullets, :bullet_id
    add_index :grid_weapon_bullets, [:grid_weapon_id, :position], unique: true
    add_foreign_key :grid_weapon_bullets, :grid_weapons
    add_foreign_key :grid_weapon_bullets, :bullets
  end
end
