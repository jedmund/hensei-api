# frozen_string_literal: true

# The skill a weapon key gives a particular weapon (α Pendulum on Scythe of Repudiation:
# α Revelation, then Ruber and Ruber II), read from the weapon's stored wiki expansion
# by WeaponSkills::KeyOptions. Display only; the calculator reads key effects elsewhere.
class CreateWeaponKeySkills < ActiveRecord::Migration[8.1]
  def change
    create_table :weapon_key_skills, id: :uuid do |t|
      t.string :weapon_granblue_id, null: false
      t.references :weapon_key, type: :uuid, null: false, foreign_key: true
      # [{ name_en:, description_en:, icon:, unlock_level:, min_uncap:, transcendence_stage: }]
      t.jsonb :versions, null: false, default: []
      t.timestamps
    end
    add_index :weapon_key_skills, %i[weapon_granblue_id weapon_key_id], unique: true
  end
end
