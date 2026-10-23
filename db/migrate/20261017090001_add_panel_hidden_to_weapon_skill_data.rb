# frozen_string_literal: true

# Some skills take effect in the in-game calculator's Estimated DMG without a line on its
# Weapon Skill Boosts panel (MjthwV: Advocatus Diaboli's main-hand Enmity). Rows flagged
# here are kept out of the panel's lines and listed apart as hidden stats.
class AddPanelHiddenToWeaponSkillData < ActiveRecord::Migration[8.1]
  def change
    add_column :weapon_skill_data, :panel_hidden, :boolean, default: false, null: false
  end
end
