# frozen_string_literal: true

namespace :granblue do
  desc "Seed weapon_skill_data from parsed JSON. Run scripts/parse_weapon_skill_data.py first."
  task seed_weapon_skill_data: :environment do
    data_file = Rails.root.join("data", "weapon_skill_data.json")

    unless File.exist?(data_file)
      puts "Error: #{data_file} not found."
      puts "Run: python3 scripts/parse_weapon_skill_data.py"
      exit 1
    end

    records = JSON.parse(File.read(data_file))
    puts "Loading #{records.size} weapon skill data rows..."

    created = 0
    updated = 0

    records.each do |record|
      datum = WeaponSkillDatum.find_or_initialize_by(
        modifier: record["modifier"],
        boost_type: record["boost_type"],
        series: record["series"],
        size: record["size"]
      )

      new_record = datum.new_record?

      datum.assign_attributes(
        formula_type: record["formula_type"],
        sl1: record["sl1"],
        sl10: record["sl10"],
        sl15: record["sl15"],
        sl20: record["sl20"],
        sl25: record["sl25"],
        coefficient: record["coefficient"],
        aura_boostable: record["aura_boostable"]
      )

      datum.save!

      if new_record
        created += 1
      else
        updated += 1
      end
    end

    puts "Done: #{created} created, #{updated} updated."
  end
end
