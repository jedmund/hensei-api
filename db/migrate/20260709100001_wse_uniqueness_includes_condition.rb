# frozen_string_literal: true

# A skill (or key) can legitimately carry two effect rows for the same boost_type +
# scaling_kind when their CONDITIONS differ — tiered key upgrades like the Δ/γ
# Pendulums grant +N at transcendence step 1 and +N more at step 4. The old indexes
# forced distinct-modifier workarounds ("Δ Pendulum (lv240)"); including condition
# makes tiered rows first-class on both the version-linked and canonical tracks.
class WseUniquenessIncludesCondition < ActiveRecord::Migration[8.0]
  def up
    remove_index :weapon_skill_effects, name: "index_wse_versioned_uniqueness"
    add_index :weapon_skill_effects, %i[weapon_skill_version_id boost_type scaling_kind condition],
              name: "index_wse_versioned_uniqueness", unique: true,
              where: "(weapon_skill_version_id IS NOT NULL)"
    remove_index :weapon_skill_effects, name: "index_wse_canonical_uniqueness"
    add_index :weapon_skill_effects, %i[modifier boost_type scaling_kind key_slug condition],
              name: "index_wse_canonical_uniqueness", unique: true,
              where: "(weapon_skill_version_id IS NULL)"
  end

  def down
    remove_index :weapon_skill_effects, name: "index_wse_versioned_uniqueness"
    add_index :weapon_skill_effects, %i[weapon_skill_version_id boost_type scaling_kind],
              name: "index_wse_versioned_uniqueness", unique: true,
              where: "(weapon_skill_version_id IS NOT NULL)"
    remove_index :weapon_skill_effects, name: "index_wse_canonical_uniqueness"
    add_index :weapon_skill_effects, %i[modifier boost_type scaling_kind key_slug],
              name: "index_wse_canonical_uniqueness", unique: true,
              where: "(weapon_skill_version_id IS NULL)"
  end
end
