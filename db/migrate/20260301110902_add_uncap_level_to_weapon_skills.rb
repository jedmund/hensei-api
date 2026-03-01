# frozen_string_literal: true

class AddUncapLevelToWeaponSkills < ActiveRecord::Migration[7.1]
  def change
    add_column :weapon_skills, :uncap_level, :integer, default: 0, null: false

    # Replace the old unique index (weapon_granblue_id, position)
    # with one that includes uncap_level, allowing multiple versions per slot.
    remove_index :weapon_skills, [:weapon_granblue_id, :position],
                 name: 'index_weapon_skills_on_weapon_granblue_id_and_position'
    add_index :weapon_skills, [:weapon_granblue_id, :position, :uncap_level],
              unique: true,
              name: 'index_weapon_skills_on_weapon_position_uncap'
  end
end
