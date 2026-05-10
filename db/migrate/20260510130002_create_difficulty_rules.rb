class CreateDifficultyRules < ActiveRecord::Migration[8.0]
  def change
    create_table :difficulty_rules, id: :uuid do |t|
      t.string :component, null: false
      t.string :rule_type, null: false
      t.jsonb :params, null: false, default: {}
      t.decimal :weight, precision: 6, scale: 2, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    add_index :difficulty_rules, :component
    add_index :difficulty_rules, :rule_type
    add_index :difficulty_rules, :active
  end
end
