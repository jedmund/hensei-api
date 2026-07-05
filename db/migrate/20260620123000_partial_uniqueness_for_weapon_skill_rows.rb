# frozen_string_literal: true

# Split the weapon_skill_data / weapon_skill_effects unique indexes into partial indexes so
# canonical (modifier-keyed) rows and per-version (description-derived) / per-key rows each have
# their own uniqueness, instead of one index that blocks version-linked rows.
class PartialUniquenessForWeaponSkillRows < ActiveRecord::Migration[8.0]
  def change
    # --- weapon_skill_data ---
    remove_index :weapon_skill_data, name: "index_weapon_skill_data_uniqueness"
    add_index :weapon_skill_data, %i[modifier boost_type series size], unique: true,
              where: "weapon_skill_version_id IS NULL", name: "index_wsd_canonical_uniqueness"
    add_index :weapon_skill_data, %i[weapon_skill_version_id boost_type series size], unique: true,
              where: "weapon_skill_version_id IS NOT NULL", name: "index_wsd_versioned_uniqueness"

    # --- weapon_skill_effects ---
    remove_index :weapon_skill_effects, name: "index_weapon_skill_effects_uniqueness"
    add_index :weapon_skill_effects, %i[modifier boost_type scaling_kind key_slug], unique: true,
              where: "weapon_skill_version_id IS NULL", name: "index_wse_canonical_uniqueness"
    add_index :weapon_skill_effects, %i[weapon_skill_version_id boost_type scaling_kind], unique: true,
              where: "weapon_skill_version_id IS NOT NULL", name: "index_wse_versioned_uniqueness"
  end
end
