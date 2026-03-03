# frozen_string_literal: true

class PopulateWeaponSkillData < ActiveRecord::Migration[8.0]
  def up
    data_file = Rails.root.join("data", "weapon_skill_data.json")
    records = JSON.parse(File.read(data_file))
    puts "Loading #{records.size} weapon skill data rows..."

    records.each do |record|
      WeaponSkillDatum.find_or_create_by!(
        modifier: record["modifier"],
        boost_type: record["boost_type"],
        series: record["series"],
        size: record["size"]
      ) do |datum|
        datum.formula_type = record["formula_type"]
        datum.sl1 = record["sl1"]
        datum.sl10 = record["sl10"]
        datum.sl15 = record["sl15"]
        datum.sl20 = record["sl20"]
        datum.sl25 = record["sl25"]
        datum.coefficient = record["coefficient"]
        datum.aura_boostable = record["aura_boostable"]
      end
    end

    puts "Done."
  end

  def down
    WeaponSkillDatum.delete_all
  end
end
