# frozen_string_literal: true

class CreateCharacterSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :character_skills, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :character_granblue_id, null: false
      t.string :kind, null: false
      t.integer :position, null: false
      t.string :game_action_id
      t.timestamps
    end

    add_index :character_skills, %i[character_granblue_id kind position],
              unique: true, name: 'idx_character_skills_unique_slot'
    add_index :character_skills, :character_granblue_id
  end
end
