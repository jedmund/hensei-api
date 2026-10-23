# frozen_string_literal: true

# 8Hm8De, captured in Arcarum, shows Sephira Salire's "take DMG worth 40% of max HP"
# as HP DMG 40 in orange: 40 is the line's cap, so it's flagged at 40, not only above.
class SetHpDmgDisplayCap < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillBoostType.where(key: "hp_dmg").update_all(display_cap: 40)
  end

  def down
    WeaponSkillBoostType.where(key: "hp_dmg").update_all(display_cap: nil)
  end
end
