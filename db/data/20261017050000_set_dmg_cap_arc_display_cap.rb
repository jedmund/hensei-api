# frozen_string_literal: true

# LgXJEi, captured in Arcarum, shows Sephira Maxi-Earth's Arcarum boost as
# "DMG Cap (Arc)" 20 in orange: the line is at its cap, the same 20 as DMG Cap.
class SetDmgCapArcDisplayCap < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillBoostType.where(key: "dmg_cap_arc").update_all(display_cap: 20)
  end

  def down
    WeaponSkillBoostType.where(key: "dmg_cap_arc").update_all(display_cap: nil)
  end
end
