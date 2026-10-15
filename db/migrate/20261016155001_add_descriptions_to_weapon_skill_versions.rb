# frozen_string_literal: true

# Each skill tier carries its own text. Skill#description_* is shared by name across
# weapons and tiers, so one weapon's text leaked into another's (Celestial tier I showed
# tier II's E. ATK). NULL means "not backfilled yet": readers fall back to the skill.
class AddDescriptionsToWeaponSkillVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :weapon_skill_versions, :description_en, :text
    add_column :weapon_skill_versions, :description_jp, :text
  end
end
