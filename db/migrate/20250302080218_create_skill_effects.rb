class CreateSkillEffects < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_effects, id: :uuid do |t|
      t.references :skill, type: :uuid, null: false
      t.references :effect, type: :uuid, null: false
      t.integer :target_type # 1=self, 2=ally, 3=all allies, 4=enemy, 5=all enemies
      t.integer :duration_type # 1=turns, 2=seconds, 3=indefinite, 4=one-time
      t.integer :duration_value # number of turns/seconds if applicable
      t.text :condition # condition text
      t.integer :chance # percentage chance to apply
      t.decimal :value # value for effect if applicable
      t.decimal :cap # cap for effect if applicable
      t.boolean :local, default: true # local vs global effect
      t.boolean :permanent, default: false # permanent
      t.boolean :undispellable, default: false # can't be dispelled
      t.timestamps null: false
    end

    add_foreign_key :skill_effects, :skills, name: 'fk_skill_effects_skills'
    add_foreign_key :skill_effects, :effects, name: 'fk_skill_effects_effects'
    add_index :skill_effects, %i[skill_id effect_id target_type]
  end
end
