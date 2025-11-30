class CreateCollectionSummons < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_summons, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :summon, type: :uuid, null: false, foreign_key: true
      t.integer :uncap_level, default: 0, null: false
      t.integer :transcendence_step, default: 0, null: false

      t.timestamps
    end

    add_index :collection_summons, [:user_id, :summon_id], unique: true
  end
end