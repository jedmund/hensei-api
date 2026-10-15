# frozen_string_literal: true

# The weapon-skill build stores what it last built each weapon from, so a run without
# all=true rebuilds only the weapons whose sources, overlay entries or build version changed.
class AddWeaponSkillBuildFingerprint < ActiveRecord::Migration[8.1]
  def change
    add_column :weapons, :weapon_skill_build_fingerprint, :string
    add_column :weapons, :weapon_skill_built_at, :datetime
  end
end
