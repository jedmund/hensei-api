# frozen_string_literal: true

# Ray of Zhuque Regus was imported with Pontus's granblue_id (1040906600). Skills are keyed by
# granblue_id, so Regus showed Pontus's skills (Wings of Divinity instead of Fire's Aegis).
# The wiki page gives Regus 1040906500. Its skills are rebuilt from the stored wikitext;
# nothing is fetched.
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
    return say("no stored wikitext for Regus; skills not rebuilt") if regus.wiki_raw.blank?

    Granblue::EntityReparser.new(regus.reload, refetch: false).reparse
    say "Regus skills: #{regus.weapon_skills.reload.count}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
