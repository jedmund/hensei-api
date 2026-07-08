# frozen_string_literal: true

# #62 phase 1: curations become inputs to reparse instead of casualties of it.
# Reparse writes the derived skill_modifier/skill_series/skill_size columns; the
# calculator resolves through the override when present. suppressed_boosts lists
# boost_types whose parsed clauses must not produce contributions (Astral Claw's
# one-foe multiattack cap, True Phantom's panel-absent HP half).
class AddClassificationOverridesToWeaponSkillVersions < ActiveRecord::Migration[8.0]
  def change
    change_table :weapon_skill_versions, bulk: true do |t|
      t.string :modifier_override
      t.string :series_override
      t.string :size_override
      t.jsonb :suppressed_boosts, default: [], null: false
      t.datetime :overrides_edited_at
    end
  end
end
