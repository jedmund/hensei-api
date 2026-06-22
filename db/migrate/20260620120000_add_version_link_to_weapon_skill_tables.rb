# frozen_string_literal: true

# Description-driven extraction writes per-version weapon_skill_data / weapon_skill_effects
# for skills that have no canonical modifier-keyed curve (composite/flavor/main-weapon skills,
# e.g. "Mikill Las", "My Words for You"). Link those rows directly to the weapon_skill_version
# so the calculator resolves them without a modifier or an icon.
class AddVersionLinkToWeaponSkillTables < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_skill_data, :weapon_skill_version_id, :uuid
    add_index :weapon_skill_data, :weapon_skill_version_id

    add_column :weapon_skill_effects, :weapon_skill_version_id, :uuid
    add_index :weapon_skill_effects, :weapon_skill_version_id
  end
end
