class CreateWeaponSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skills, id: :uuid do |t|
      t.string :weapon_granblue_id, null: false
      t.references :skill, type: :uuid, null: false
      t.integer :position, null: false # 1, 2, 3 for skill slots
      t.string :skill_modifier # Modifier like "Might", "Majesty"
      t.string :skill_series # Series like "Ironflame", "Hoarfrost"
      t.string :skill_size # Size like "Small", "Medium", "Big", "Massive"
      t.integer :unlock_level # level when skill unlocked
      t.timestamps null: false
    end

    add_foreign_key :weapon_skills, :skills
    add_index :weapon_skills, %i[weapon_granblue_id position]
    add_index :weapon_skills, :weapon_granblue_id
    add_index :weapon_skills, :skill_series
  end
end
