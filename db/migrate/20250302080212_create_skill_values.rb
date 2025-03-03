class CreateSkillValues < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_values, id: :uuid do |t|
      t.references :skill, type: :uuid, null: false
      t.integer :level, null: false, default: 1 # skill level or uncap level
      t.decimal :value # numeric value for multiplier
      t.string :text_value # text description for non-numeric values
      t.timestamps null: false
    end

    add_foreign_key :skill_values, :skills
    add_index :skill_values, %i[skill_id level], unique: true
  end
end
