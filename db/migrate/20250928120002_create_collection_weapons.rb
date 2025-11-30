class CreateCollectionWeapons < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_weapons, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :weapon, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0

      t.references :weapon_key1, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.references :weapon_key2, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.references :weapon_key3, type: :uuid, foreign_key: { to_table: :weapon_keys }
      t.references :weapon_key4, type: :uuid, foreign_key: { to_table: :weapon_keys }

      t.references :awakening, type: :uuid, foreign_key: true
      t.integer :awakening_level, default: 1, null: false

      t.integer :ax_modifier1
      t.float :ax_strength1
      t.integer :ax_modifier2
      t.float :ax_strength2
      t.integer :element

      t.timestamps
    end

    add_index :collection_weapons, [:user_id, :weapon_id], unique: true
  end
end