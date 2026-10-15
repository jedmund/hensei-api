# frozen_string_literal: true

# Rebuilds skills for two groups of weapons the earlier imports got wrong.
#
# Series-template pages ({{Weapon/Common/…}}) carry only the Japanese skill lines, but the
# "is there English skill text?" check matched "s1_desc=" inside "|jps1_desc=", so 45 of
# them were parsed structurally from text that isn't there instead of being expanded.
# Reparsing a Celestial weapon dropped its Splendor and Voltage slots, and three Proven
# weapons never got their "Armed" skill.
#
# Separately, SSR weapons whose skills were never persisted are refetched and parsed
# (Odious, Grand, collab and others). Revenant variants and weapons without a wiki page
# are left as they are.
#
# Both steps fetch from gbf.wiki; a weapon that fails is logged and skipped so a wiki
# outage can't block the deploy. Curated rows survive (EntityReparser restores them).
class ReparseMisroutedAndSkilllessWeapons < ActiveRecord::Migration[8.0]
  def up
    [WeaponSkill, WeaponSkillVersion, WeaponSkillDatum, WeaponSkillEffect].each(&:reset_column_information)
    english = Granblue::Extractors::ExpandedWeaponSkillImporter::ENGLISH_S1_DESC_SQL

    misrouted = Weapon.where("wiki_raw LIKE ? AND wiki_raw ILIKE ? AND wiki_raw !~ ?",
                             "%{{Weapon/Common/%", "%s1_desc=%", english).to_a
    skillless = Weapon.left_joins(:weapon_skills).where(weapon_skills: { id: nil }, rarity: 3)
                      .where.not(wiki_raw: [nil, ""]).to_a

    report(:misrouted, misrouted.map { |w| reparse(w, refetch: false) })
    report(:skillless, skillless.map { |w| reparse(w, refetch: true) })
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "regenerated rows follow the parser"
  end

  private

  def reparse(weapon, refetch:)
    Granblue::EntityReparser.new(weapon, refetch: refetch).reparse
    sleep 0.2
    weapon.weapon_skills.reload.any? ? :ok : :empty
  rescue StandardError => e
    say "  #{weapon.name_en}: #{e.class}: #{e.message.to_s[0, 100]}"
    :failed
  end

  def report(group, results)
    say "#{group}: #{results.tally.sort.to_h}"
  end
end
