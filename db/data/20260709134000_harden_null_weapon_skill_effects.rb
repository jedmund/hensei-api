# frozen_string_literal: true

class HardenNullWeaponSkillEffects < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET value = 10.0,
          value_unit = 'percent',
          total_cap = 30.0,
          notes = '10% Special C.A. DMG Cap from family template; WpnSkillAscendancy states it stacks to 30%.'
      WHERE modifier = 'Ascendancy'
        AND boost_type = 'sp_ca_cap'
        AND scaling_kind = 'flat'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'documentation'
      WHERE modifier = 'Bloodshed'
        AND boost_type = 'hp_dmg'
        AND scaling_kind = 'static'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'documentation'
      WHERE modifier = 'Essence'
        AND boost_type = 'atk'
        AND scaling_kind = 'static'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'documentation'
      WHERE modifier = 'Insignia'
        AND boost_type = 'turn_dmg'
        AND scaling_kind = 'per_grid_count'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET value = NULL,
          value_unit = 'percent',
          total_cap = 30.0,
          notes = 'VERIFY: per-copy value not in prose; Sp. C.A. DMG Cap Up stacks to 30%.'
      WHERE modifier = 'Ascendancy'
        AND boost_type = 'sp_ca_cap'
        AND scaling_kind = 'flat'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'static'
      WHERE modifier = 'Bloodshed'
        AND boost_type = 'hp_dmg'
        AND scaling_kind = 'documentation'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'static'
      WHERE modifier = 'Essence'
        AND boost_type = 'atk'
        AND scaling_kind = 'documentation'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'per_grid_count'
      WHERE modifier = 'Insignia'
        AND boost_type = 'turn_dmg'
        AND scaling_kind = 'documentation'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL
  end
end
