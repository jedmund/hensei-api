class CreateDifficultyComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :difficulty_components, id: :uuid do |t|
      t.string :name, null: false
      t.decimal :weight, precision: 6, scale: 2, null: false, default: 1
      t.boolean :enabled, null: false, default: true
      t.integer :min_count_to_score, null: false, default: 0
      t.timestamps
    end

    add_index :difficulty_components, :name, unique: true
  end
end
