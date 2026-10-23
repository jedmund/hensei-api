class CreateSupportSummons < ActiveRecord::Migration[8.0]
  def change
    create_table :support_summons, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :collection_summon, type: :uuid, null: false, foreign_key: true
      t.integer :section, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :support_summons, [:user_id, :section, :position], unique: true
  end
end
