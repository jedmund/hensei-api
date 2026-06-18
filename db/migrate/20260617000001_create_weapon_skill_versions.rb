# frozen_string_literal: true

class CreateWeaponSkillVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skill_versions, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :weapon_skill, type: :uuid, null: false, foreign_key: true, index: true
      t.references :skill, type: :uuid, null: false, foreign_key: true, index: true
      t.integer :ordinal, null: false
      t.integer :unlock_level
      t.integer :min_uncap
      t.integer :transcendence_stage, null: false, default: 0
      t.string :icon
      t.string :skill_modifier
      t.string :skill_series
      t.string :skill_size
      t.boolean :main_hand_only, null: false, default: false
      t.boolean :mc_only, null: false, default: false
      t.boolean :scales_with_skill_level, null: false, default: true
      t.timestamps
    end

    add_index :weapon_skill_versions, %i[weapon_skill_id ordinal],
              unique: true, name: 'idx_weapon_skill_versions_on_skill_and_ordinal'
    add_index :weapon_skill_versions, :skill_series
  end
end
