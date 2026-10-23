# frozen_string_literal: true

class CanonicalizeHeroicTaleCondition < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'conditional_flat',
          condition = '{"type":"count_basis_gte","basis":"distinct_weapon_types","gte":10}'::jsonb,
          updated_at = CURRENT_TIMESTAMP
      WHERE modifier = 'Heroic Tale'
        AND boost_type IN ('atk', 'dmg_cap')
        AND weapon_skill_version_id IS NOT NULL
        AND manually_edited_at IS NULL
        AND weapon_skill_version_id IN (
          SELECT weapon_skill_versions.id
          FROM weapon_skill_versions
          INNER JOIN weapon_skills ON weapon_skills.id = weapon_skill_versions.weapon_skill_id
          WHERE weapon_skills.weapon_granblue_id = '1040311100'
        )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'static',
          condition = '{}'::jsonb,
          updated_at = CURRENT_TIMESTAMP
      WHERE modifier = 'Heroic Tale'
        AND boost_type = 'atk'
        AND weapon_skill_version_id IS NOT NULL
        AND manually_edited_at IS NULL
        AND weapon_skill_version_id IN (
          SELECT weapon_skill_versions.id
          FROM weapon_skill_versions
          INNER JOIN weapon_skills ON weapon_skills.id = weapon_skill_versions.weapon_skill_id
          WHERE weapon_skills.weapon_granblue_id = '1040311100'
        )
    SQL

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET condition = '{"type":"weapon_group_count","gte":0,"all":true}'::jsonb,
          updated_at = CURRENT_TIMESTAMP
      WHERE modifier = 'Heroic Tale'
        AND boost_type = 'dmg_cap'
        AND scaling_kind = 'conditional_flat'
        AND weapon_skill_version_id IS NOT NULL
        AND manually_edited_at IS NULL
        AND weapon_skill_version_id IN (
          SELECT weapon_skill_versions.id
          FROM weapon_skill_versions
          INNER JOIN weapon_skills ON weapon_skills.id = weapon_skill_versions.weapon_skill_id
          WHERE weapon_skills.weapon_granblue_id = '1040311100'
        )
    SQL
  end
end
