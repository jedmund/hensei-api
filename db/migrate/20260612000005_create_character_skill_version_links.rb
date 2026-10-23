# frozen_string_literal: true

class CreateCharacterSkillVersionLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :character_skill_version_links, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.uuid :from_version_id, null: false
      t.uuid :to_version_id, null: false
      t.string :relation, null: false
      t.timestamps
    end

    add_foreign_key :character_skill_version_links, :character_skill_versions, column: :from_version_id
    add_foreign_key :character_skill_version_links, :character_skill_versions, column: :to_version_id
    add_index :character_skill_version_links, :from_version_id
    add_index :character_skill_version_links, :to_version_id
    add_index :character_skill_version_links, %i[from_version_id to_version_id relation],
              unique: true, name: 'idx_character_skill_version_links_unique'
  end
end
