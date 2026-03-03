# frozen_string_literal: true

class PopulateMissingWeaponSkillData < ActiveRecord::Migration[8.0]
  def up
    data_file = Rails.root.join("data", "weapon_skill_data.json")
    records = JSON.parse(File.read(data_file))

    created = 0
    records.each do |record|
      datum = WeaponSkillDatum.find_or_create_by!(
        modifier: record["modifier"],
        boost_type: record["boost_type"],
        series: record["series"],
        size: record["size"]
      ) do |d|
        d.formula_type = record["formula_type"]
        d.sl1 = record["sl1"]
        d.sl10 = record["sl10"]
        d.sl15 = record["sl15"]
        d.sl20 = record["sl20"]
        d.sl25 = record["sl25"]
        d.coefficient = record["coefficient"]
        d.aura_boostable = record["aura_boostable"]
        created += 1
      end
    end

    puts "Created #{created} new weapon skill data rows (#{WeaponSkillDatum.count} total)."
  end

  def down
    new_modifiers = %w[
      Aramis Athos Fathoms Godblade Godflair Godheart Godshield Godstrike
      Honing Porthos Ruination
    ] + [
      "Draconic Barrier", "Draconic Fortitude", "Draconic Magnitude",
      "Draconic Progression", "Fulgor Elatio", "Fulgor Fortis",
      "Fulgor Impetus", "Fulgor Sanatio", "Scandere Aggressio",
      "Scandere Arcanum", "Scandere Catena", "Scandere Facultas",
      "True Dragon Barrier"
    ]

    WeaponSkillDatum.where(modifier: new_modifiers).delete_all
    WeaponSkillDatum.where(modifier: "Supremacy: Decimation", boost_type: "dmg_cap").delete_all
  end
end
