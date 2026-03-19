class CreateCollectionWeaponBullets < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_weapon_bullets, id: :uuid do |t|
      t.uuid :collection_weapon_id, null: false
      t.uuid :bullet_id, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :collection_weapon_bullets, :collection_weapon_id
    add_index :collection_weapon_bullets, :bullet_id
    add_index :collection_weapon_bullets, [:collection_weapon_id, :position], unique: true, name: 'idx_collection_weapon_bullets_unique'
    add_foreign_key :collection_weapon_bullets, :collection_weapons
    add_foreign_key :collection_weapon_bullets, :bullets
  end
end
