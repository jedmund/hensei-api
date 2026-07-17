# frozen_string_literal: true

class BackfillFortifiedGauntletModifier < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_versions
      SET skill_modifier = 'Fortified Gauntlet'
      FROM weapon_skills, weapons, skills
      WHERE weapon_skill_versions.weapon_skill_id = weapon_skills.id
        AND weapon_skills.weapon_granblue_id = weapons.granblue_id
        AND weapon_skill_versions.skill_id = skills.id
        AND weapons.name_en = 'Arkab Prior Militis'
        AND skills.name_en = 'Fortified Gauntlet'
        AND weapon_skill_versions.skill_modifier = 'Gauntlet'
        AND weapon_skill_versions.modifier_override IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_versions
      SET skill_modifier = 'Gauntlet'
      FROM weapon_skills, weapons, skills
      WHERE weapon_skill_versions.weapon_skill_id = weapon_skills.id
        AND weapon_skills.weapon_granblue_id = weapons.granblue_id
        AND weapon_skill_versions.skill_id = skills.id
        AND weapons.name_en = 'Arkab Prior Militis'
        AND skills.name_en = 'Fortified Gauntlet'
        AND weapon_skill_versions.skill_modifier = 'Fortified Gauntlet'
        AND weapon_skill_versions.modifier_override IS NULL
    SQL
  end
end
