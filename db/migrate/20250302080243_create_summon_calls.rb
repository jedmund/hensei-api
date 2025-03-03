class CreateSummonCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :summon_calls, id: :uuid do |t|
      t.string :summon_granblue_id, null: false
      t.references :skill, type: :uuid, null: false
      t.integer :cooldown
      t.integer :uncap_level # 0, 3, 4, 5 for uncap level
      t.references :alt_skill, type: :uuid
      t.text :alt_condition # condition for alt version
      t.timestamps null: false
    end

    add_foreign_key :summon_calls, :skills
    add_foreign_key :summon_calls, :skills, column: :alt_skill_id
    add_index :summon_calls, %i[summon_granblue_id uncap_level]
    add_index :summon_calls, :summon_granblue_id
  end
end
