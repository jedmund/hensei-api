class CreateCharacterSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :character_skills, id: :uuid do |t|
      t.string :character_granblue_id, null: false
      t.references :skill, type: :uuid, null: false
      t.integer :position, null: false # 1, 2, 3, 4 for skill slots
      t.integer :unlock_level # level when skill unlocked
      t.integer :improve_level # level when skill improved (+)
      t.references :alt_skill, type: :uuid
      t.text :alt_condition # condition for alt version
      t.timestamps null: false
    end

    add_foreign_key :character_skills, :skills
    add_foreign_key :character_skills, :skills, column: :alt_skill_id
    add_index :character_skills, %i[character_granblue_id position]
    add_index :character_skills, :character_granblue_id
  end
end
