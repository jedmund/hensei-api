# frozen_string_literal: true

namespace :granblue do
  desc "Seed weapon_skill_boost_types from JSON reference data."
  task seed_weapon_skill_boost_types: :environment do
    data_file = Rails.root.join("data", "weapon_skill_boost_types.json")

    unless File.exist?(data_file)
      puts "Error: #{data_file} not found."
      exit 1
    end

    records = JSON.parse(File.read(data_file))
    puts "Loading #{records.size} weapon skill boost types..."

    created = 0
    updated = 0

    records.each do |record|
      boost_type = WeaponSkillBoostType.find_or_initialize_by(key: record["key"])

      new_record = boost_type.new_record?

      boost_type.assign_attributes(
        name_en: record["name_en"],
        name_jp: record["name_jp"],
        category: record["category"],
        grid_cap: record["grid_cap"],
        cap_is_flat: record["cap_is_flat"],
        stacking_rule: record["stacking_rule"],
        notes: record["notes"]
      )

      boost_type.save!

      if new_record
        created += 1
      else
        updated += 1
      end
    end

    puts "Done: #{created} created, #{updated} updated."
  end
end
