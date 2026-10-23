# frozen_string_literal: true

# Re-runs the description extractor over every weapon after the parser stopped turning
# proc and condition text into passive boosts (heals, "N% chance", "upon …" actions, HP
# thresholds and costs, foe/MC status conditions, "From a …:" triggers, a critical hit
# damage cap read as Critical) and learned plain Skill DMG. The extractor works from
# the stored wikitext, leaves hand-curated rows alone and purges the generated rows a
# skill no longer yields.
#
# True <X>'s Supremacy reads "Massive boost to ATK. Small boost to max HP.", but the
# wiki's True Supremacy table lists that HP (14.5/16) under the Massive tier. Now that
# the parser splits after "ATK.", HP would pick a Small curve, so those rows are pinned
# as curated first (atSjtJ: HP 16 at level 200).
class ReparseWeaponSkillDescriptions < ActiveRecord::Migration[8.0]
  def up
    # Ran on prod before the weapon-skill build replaced the extractor (W8 gate 4).
    unless defined?(Granblue::Extractors::WeaponSkillDescriptionExtractor)
      return say("WeaponSkillDescriptionExtractor is gone (the weapon-skill build writes these rows); skipping")
    end

    [WeaponSkillDatum, WeaponSkillEffect, WeaponSkillVersion].each(&:reset_column_information)

    WeaponSkillDatum.joins(weapon_skill_version: :skill)
                    .where("skills.name_en LIKE 'True %Supremacy'")
                    .where(boost_type: "hp", manually_edited_at: nil)
                    .update_all(manually_edited_at: Time.current, provenance: "manual")

    before = [WeaponSkillEffect.count, WeaponSkillDatum.count]
    stats = Granblue::Extractors::WeaponSkillDescriptionExtractor.run
    say "reparsed: effects #{before[0]} -> #{WeaponSkillEffect.count}, data #{before[1]} -> " \
        "#{WeaponSkillDatum.count} (#{stats.slice(:effect_rows, :data_rows, :no_clause).to_h})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "regenerated rows follow the parser"
  end
end
