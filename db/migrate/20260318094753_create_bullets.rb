class CreateBullets < ActiveRecord::Migration[8.0]
  def change
    create_table :bullets, id: :uuid do |t|
      t.string :granblue_id
      t.string :name_en, null: false
      t.string :name_jp
      t.string :effect_en
      t.string :effect_jp
      t.string :slug, null: false
      t.integer :bullet_type, null: false
      t.integer :atk, default: 0, null: false
      t.boolean :hits_all, default: false, null: false
      t.integer :order, default: 0, null: false

      t.timestamps
    end

    add_index :bullets, :granblue_id, unique: true
    add_index :bullets, :slug, unique: true
    add_index :bullets, :bullet_type
  end
end
