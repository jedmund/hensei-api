# frozen_string_literal: true

class AddMaxValueToWeaponSkillData < ActiveRecord::Migration[8.0]
  def change
    # Progression skills store a per-turn value (in sl*) plus an individual
    # maximum the accrual caps at. Other formula types leave this null.
    add_column :weapon_skill_data, :max_value, :decimal, precision: 10, scale: 4
  end
end
