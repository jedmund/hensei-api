class CreateDifficulties < ActiveRecord::Migration[8.0]
  def change
    create_table :difficulties, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.decimal :min_score, precision: 5, scale: 2, null: false, default: 0
      t.decimal :max_score, precision: 5, scale: 2, null: false, default: 100
      t.integer :sort_order, null: false, default: 0
      t.string :color
      t.timestamps
    end

    add_index :difficulties, :slug, unique: true
    add_index :difficulties, :sort_order
  end
end
