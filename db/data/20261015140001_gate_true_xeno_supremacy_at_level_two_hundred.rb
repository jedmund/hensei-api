# frozen_string_literal: true

# True Xeno weapons upgrade their first skill to "True <X>'s Supremacy" (ATK and max HP)
# at weapon level 200 (Template:Weapon/Common/True Xeno, s1_4s_lvl=200). The imported
# True versions applied from 3★, so they also replaced the ATK-only base skill below
# level 200. P8fDVY/atSjtJ show it: the same Advocatus Diaboli adds no HP below level 200
# and HP 16 at level 200.
class GateTrueXenoSupremacyAtLevelTwoHundred < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillVersion.reset_column_information
    series = WeaponSeries.find_by(slug: "xeno") or return

    WeaponSkillVersion.joins(:skill, weapon_skill: :weapon)
                      .where(weapons: { weapon_series_id: series.id })
                      .where("skills.name_en LIKE 'True %''s Supremacy'")
                      .update_all(unlock_level: 200, min_uncap: 5)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the previous gates were missing, not chosen"
  end
end
