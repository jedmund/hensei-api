# frozen_string_literal: true

# Version-linked data and effects belong to their version: deleting the version
# deletes them, and a row can't point at a version that doesn't exist. Runs after
# the orphan cleanup (data migration 20261016100002).
class AddWeaponSkillVersionForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :weapon_skill_data, :weapon_skill_versions, on_delete: :cascade
    add_foreign_key :weapon_skill_effects, :weapon_skill_versions, on_delete: :cascade
  end
end
