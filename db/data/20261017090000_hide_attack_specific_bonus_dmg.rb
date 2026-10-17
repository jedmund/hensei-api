# frozen_string_literal: true

# Bonus DMG on single attacks (bonus_elem_dmg_single) or triple attacks only
# (bonus_elem_dmg_ta, Sol Remnant's Astral Blow II) has no panel line in game (X53WHq).
# Neither key had a boost type, so the calculator listed them under their raw key
# ("bonus elem dmg ta 10%"). Registering them as hidden keeps them off the panel.
class HideAttackSpecificBonusDmg < ActiveRecord::Migration[8.0]
  KEYS = {
    "bonus_elem_dmg_single" => "Bonus Elem. DMG (Single Attack)",
    "bonus_elem_dmg_ta" => "Bonus Elem. DMG (Triple Attack)"
  }.freeze

  def up
    WeaponSkillBoostType.reset_column_information
    KEYS.each do |key, name|
      WeaponSkillBoostType.find_or_initialize_by(key: key).update!(
        name_en: name, category: "offensive", stacking_rule: "additive", hidden: true
      )
    end
  end

  def down
    WeaponSkillBoostType.where(key: KEYS.keys).delete_all
  end
end
