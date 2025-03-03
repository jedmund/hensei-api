class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp
      t.text :description_en
      t.text :description_jp
      t.integer :border_type # 1=red(dmg), 2=green(heal), 3=yellow(buff), 4=blue(debuff), 5=purple(field)
      t.integer :cooldown
      t.integer :skill_type # 1=character, 2=weapon, 3=summon call, 4=charge attack
      t.timestamps null: false
    end

    add_index :skills, :name_en
    add_index :skills, :skill_type
  end
end
