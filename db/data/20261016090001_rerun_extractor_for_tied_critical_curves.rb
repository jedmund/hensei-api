# frozen_string_literal: true

# The description extractor's fallback curve picked between tied canonical rows by
# database row order, so a restored database could derive different values than prod.
# The tie-break is now deterministic; re-extract the three weapons whose Critical (Big)
# row depended on it (SL20 becomes 11, as on the Celere and Verity curves). Offline.
class RerunExtractorForTiedCriticalCurves < ActiveRecord::Migration[8.0]
  WEAPONS = %w[1030504300 1040518700 1040709700].freeze

  def up
    # Ran on prod before the weapon-skill build replaced the extractor (W8 gate 4).
    unless defined?(Granblue::Extractors::WeaponSkillDescriptionExtractor)
      return say("WeaponSkillDescriptionExtractor is gone (the weapon-skill build writes these rows); skipping")
    end

    [WeaponSkillDatum, WeaponSkillEffect, WeaponSkillVersion].each(&:reset_column_information)
    Weapon.where(granblue_id: WEAPONS).find_each do |weapon|
      Granblue::Extractors::WeaponSkillDescriptionExtractor.run(weapon: weapon)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "regenerated rows follow the extractor"
  end
end
