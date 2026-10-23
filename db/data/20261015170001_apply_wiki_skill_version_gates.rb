# frozen_string_literal: true

# Raises the unlock gates of 79 skill versions that applied a tier early, to the levels
# gbf.wiki gives (db/data/manifests/skill_version_gates.json): hand-added Cosmic, Astral,
# New World, Exo and Revans Mk II rows that were never gated, template defaults the
# importer dropped (Proven, Epic, Illustrious), and two True Xeno copies the earlier
# True Supremacy gate missed (True Glacial Supremacy has no "'s").
#
# Exo's "<X>'s Supremacy: Decimation" is the 5★ form of the first skill ("Massive boost
# to ATK. 5% boost to DMG cap") and now replaces the base skill in the calculator; its
# DMG cap was stored at skill level 1 only, so it read 0 at higher levels.
#
# The manifest is now `gate` ops in the curation overlay (data/weapon_skill_curation/),
# which the deploy sync applies; this migration skips it once the file is gone.
class ApplyWikiSkillVersionGates < ActiveRecord::Migration[8.0]
  MANIFEST = "db/data/manifests/skill_version_gates.json"

  def up
    [WeaponSkillVersion, WeaponSkillDatum].each(&:reset_column_information)
    if File.exist?(Rails.root.join(MANIFEST))
      gates = JSON.parse(File.read(Rails.root.join(MANIFEST))).fetch("gates")
      unmatched = gates.count { |gate| apply(gate).zero? }
      say "#{gates.size} gates, #{unmatched} matched nothing"
    else
      say "#{MANIFEST} is gone: the gates are curation overlay ops now"
    end

    WeaponSkillDatum.where(weapon_skill_version_id: nil, modifier: "Supremacy: Decimation", boost_type: "dmg_cap")
                    .update_all(sl1: 5, sl10: 5, sl15: 5, sl20: 5, sl25: 5)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the previous gates were missing, not chosen"
  end

  private

  def apply(gate)
    WeaponSkillVersion.joins(:skill, :weapon_skill)
                      .where(weapon_skills: { weapon_granblue_id: gate.fetch("granblue_id") },
                             skills: { name_en: gate.fetch("skill") })
                      .update_all(unlock_level: gate["unlock_level"], min_uncap: gate.fetch("min_uncap"),
                                  transcendence_stage: gate.fetch("transcendence_stage"))
  end
end
