# frozen_string_literal: true

class PopulateWeaponSkillBoostTypes < ActiveRecord::Migration[8.0]
  def up
    data_file = Rails.root.join("data", "weapon_skill_boost_types.json")
    records = JSON.parse(File.read(data_file))
    puts "Loading #{records.size} weapon skill boost types..."

    records.each do |record|
      WeaponSkillBoostType.find_or_create_by!(key: record["key"]) do |bt|
        bt.name_en = record["name_en"]
        bt.name_jp = record["name_jp"]
        bt.category = record["category"]
        bt.grid_cap = record["grid_cap"]
        bt.cap_is_flat = record["cap_is_flat"]
        bt.stacking_rule = record["stacking_rule"]
        bt.notes = record["notes"]
      end
    end

    puts "Done."
  end

  def down
    WeaponSkillBoostType.delete_all
  end
end
