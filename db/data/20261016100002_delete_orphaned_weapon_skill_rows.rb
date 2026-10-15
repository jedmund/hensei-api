# frozen_string_literal: true

# Version-linked weapon_skill_data/effects whose version no longer exists. The
# calculator never reads them. On the 2026-10-15 catalogue they are 10
# manually-edited Sephira Maxi-Water dmg_cap effects, left behind when their
# versions were destroyed. The live Sephira Maxi-Water versions carry the same
# curated rows. Removing them lets the foreign keys in the next migration go on.
class DeleteOrphanedWeaponSkillRows < ActiveRecord::Migration[8.1]
  def up
    %w[weapon_skill_data weapon_skill_effects].each do |table|
      execute(<<~SQL.squish)
        DELETE FROM #{table} t
        WHERE t.weapon_skill_version_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM weapon_skill_versions v WHERE v.id = t.weapon_skill_version_id)
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
