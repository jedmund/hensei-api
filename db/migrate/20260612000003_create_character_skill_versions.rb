# frozen_string_literal: true

class CreateCharacterSkillVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :character_skill_versions, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :character_skill, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name_en, null: false
      t.string :name_jp
      t.text :description_en
      t.text :description_jp
      t.string :icon
      t.string :type_color
      t.integer :cooldown
      t.integer :initial_cooldown
      t.integer :duration_value
      t.string :duration_unit
      t.string :variant_role, null: false
      t.integer :ordinal, null: false
      t.integer :unlock_level
      t.integer :enhance_levels, array: true, null: false, default: []
      t.integer :min_uncap
      t.integer :transcendence_stage
      t.string :trigger_type, null: false, default: 'none'
      t.string :trigger_value
      t.boolean :cant_recast, null: false, default: false
      t.boolean :one_time_use, null: false, default: false
      t.boolean :auto_activate, null: false, default: false
      t.boolean :mimicable, null: false, default: false
      t.boolean :targets_all, null: false, default: false
      t.string :game_action_id
      t.timestamps
    end

    add_index :character_skill_versions, %i[character_skill_id ordinal],
              name: 'idx_character_skill_versions_on_skill_and_ordinal'
  end
end
