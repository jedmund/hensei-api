# frozen_string_literal: true

class BackfillTriturationSkillModifier < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_versions
      SET skill_modifier = 'Trituration',
          skill_series = COALESCE(skill_series, 'omega')
      FROM skills
      WHERE weapon_skill_versions.skill_id = skills.id
        AND skills.name_en LIKE '%''s Trituration'
        AND weapon_skill_versions.skill_modifier IS NULL
        AND weapon_skill_versions.modifier_override IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_versions
      SET skill_modifier = NULL,
          skill_series = NULL
      FROM skills
      WHERE weapon_skill_versions.skill_id = skills.id
        AND skills.name_en LIKE '%''s Trituration'
        AND weapon_skill_versions.skill_modifier = 'Trituration'
        AND weapon_skill_versions.modifier_override IS NULL
    SQL
  end
end
