class CreateCollectionCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_characters, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :character, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0, null: false
      t.boolean :perpetuity, default: false, null: false
      t.references :awakening, type: :uuid, foreign_key: true
      t.integer :awakening_level, default: 1

      t.jsonb :ring1, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring2, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring3, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :ring4, default: { modifier: nil, strength: nil }, null: false
      t.jsonb :earring, default: { modifier: nil, strength: nil }, null: false

      t.timestamps
    end

    add_index :collection_characters, [:user_id, :character_id], unique: true
  end
end