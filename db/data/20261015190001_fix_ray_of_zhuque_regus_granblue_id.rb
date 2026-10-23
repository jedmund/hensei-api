# frozen_string_literal: true

# Ray of Zhuque Regus was imported with Pontus's granblue_id (1040906600). Skills are keyed by
# granblue_id, so Regus showed Pontus's skills (Wings of Divinity instead of Fire's Aegis).
# The wiki page gives Regus 1040906500.
#
# Regus's stored wikitext may itself be Pontus's page (it was fetched while the ids were
# shared), so its skills are rebuilt here only when the stored page says |id=1040906500.
# Otherwise Regus is left with no skills; granblue:rebuild_weapons_from_sources rebuilds
# skill-less weapons from stored sources after granblue:fetch_weapon_sources. Nothing is
# fetched here.
class FixRayOfZhuqueRegusGranblueId < ActiveRecord::Migration[8.0]
  PONTUS_ID = "1040906600"
  REGUS_ID = "1040906500"

  def up
    regus = Weapon.find_by(name_en: "Ray of Zhuque Regus", granblue_id: PONTUS_ID)
    return say("Regus already fixed or missing; skipping") unless regus

    if Weapon.exists?(granblue_id: REGUS_ID)
      return say("another weapon already has #{REGUS_ID}; skipping")
    end

    regus.update_columns(granblue_id: REGUS_ID)
    # The column this read (Weapon#wiki_raw reads `sources` since PR 7b, filled later by
    # 20261022110000).
    page = if column_exists?(:weapons, :wiki_raw)
             Weapon.where(id: regus.id).pick(Arel.sql("wiki_raw"))
           else
             regus.wiki_raw
           end
    stored_id = page.to_s[/^\|id=\s*(\d+)/, 1]
    return say("stored wikitext is #{stored_id || 'missing'}, not Regus; skills not rebuilt") unless stored_id == REGUS_ID

    # Since W8 gate 4 a reparse is the weapon-skill build, which needs the stored source. It reads
    # `sources` since PR 7b: a database that runs this before that table exists builds them later.
    unless table_exists?(:sources)
      return say("skills not rebuilt (no sources table yet); granblue:build_weapon_skills builds them")
    end

    begin
      Granblue::EntityReparser.new(regus.reload, refetch: false).reparse
    rescue Granblue::EntityReparser::MissingWikiRawError => e
      return say("skills not rebuilt (#{e.message}); granblue:build_weapon_skills builds them")
    end
    say "Regus skills: #{regus.weapon_skills.reload.count}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
