# frozen_string_literal: true

class PopulateElementSkillData < ActiveRecord::Migration[8.0]
  def up
    # Add shield boost type
    WeaponSkillBoostType.find_or_create_by!(key: "shield") do |bt|
      bt.name_en = "Shield"
      bt.category = "defensive"
      bt.grid_cap = nil
      bt.cap_is_flat = true
      bt.stacking_rule = "highest_only"
      bt.notes = "Flat HP shield granted at start of battle. Multiple shield weapon skills do not stack; only the highest value takes effect."
    end

    # Load and populate weapon skill data from JSON
    data_file = Rails.root.join("data", "weapon_skill_data.json")
    records = JSON.parse(File.read(data_file))

    created = 0
    records.each do |record|
      WeaponSkillDatum.find_or_create_by!(
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
    new_modifiers = [
      "Preemptive Blade", "Preemptive Wall", "Preemptive Barrier",
      "Strike: Dark", "Strike: Earth", "Strike: Fire",
      "Strike: Light", "Strike: Water", "Strike: Wind",
      "Optimus Exalto", "Omega Exalto"
    ]

    WeaponSkillDatum.where(modifier: new_modifiers).delete_all
    WeaponSkillBoostType.where(key: "shield").delete_all
  end
end
