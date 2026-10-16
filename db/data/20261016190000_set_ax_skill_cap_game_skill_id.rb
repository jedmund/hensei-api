# frozen_string_literal: true

# The Skill DMG Cap AX roll was added without its game skill id, so both
# importers logged "Unknown augment skill_id=1598" and dropped the roll.
# 1598 is the only id missing from the 1588-1601 AX run, and an in-game
# capture (ATK 2.5 + Skill DMG Cap 1) confirms it.
class SetAxSkillCapGameSkillId < ActiveRecord::Migration[8.0]
  SLUG = "ax_skill_cap"
  GAME_SKILL_ID = 1598

  def up
    WeaponStatModifier.reset_column_information
    WeaponStatModifier.where(slug: SLUG).update_all(game_skill_id: GAME_SKILL_ID)
  end

  def down
    WeaponStatModifier.where(slug: SLUG, game_skill_id: GAME_SKILL_ID).update_all(game_skill_id: nil)
  end
end
