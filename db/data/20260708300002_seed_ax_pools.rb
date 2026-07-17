# frozen_string_literal: true

# gbf.wiki/AX_Skills: per-primary secondary pools for the standard series
# (Omega/Primal/Ancestral) and Xeno, secondary value ranges, and the missing
# Skill DMG Cap secondary. Primal weapons can additionally roll EXP/Rupie
# primaries (the Ancient weapons roll ONLY those — ax_type 'utility').
class SeedAxPools < ActiveRecord::Migration[8.0]
  POOLS = {
    "ax_atk" => { "standard" => %w[ax_ca_dmg ax_da ax_ta ax_skill_cap],
                  "xeno" => %w[ax_ca_dmg ax_multiattack ax_na_cap ax_skill_supp] },
    "ax_def" => { "standard" => %w[ax_hp ax_debuff_res ax_healing ax_enmity],
                  "xeno" => %w[ax_ele_dmg_red ax_debuff_res ax_healing ax_enmity] },
    "ax_hp" => { "standard" => %w[ax_def ax_debuff_res ax_healing ax_stamina],
                 "xeno" => %w[ax_ele_dmg_red ax_debuff_res ax_healing ax_stamina] },
    "ax_ca_dmg" => { "standard" => %w[ax_atk ax_ele_atk ax_ca_cap ax_stamina],
                     "xeno" => %w[ax_multiattack ax_skill_supp ax_ca_supp ax_stamina] },
    "ax_multiattack" => { "standard" => %w[ax_ca_dmg ax_ele_atk ax_da ax_ta],
                          "xeno" => %w[ax_ca_supp ax_na_cap ax_stamina ax_enmity] }
  }.freeze

  SECONDARY_RANGES = {
    "ax_atk" => [1, 1.5], "ax_ele_atk" => [1, 5], "ax_na_cap" => [0.5, 1.5],
    "ax_def" => [1, 3], "ax_hp" => [1, 3], "ax_debuff_res" => [1, 3],
    "ax_healing" => [2, 5], "ax_ele_dmg_red" => [1, 5], "ax_stamina" => [1, 3],
    "ax_enmity" => [1, 3], "ax_ca_dmg" => [2, 4], "ax_ca_cap" => [1, 2],
    "ax_ca_supp" => [1, 5], "ax_skill_cap" => [1, 2], "ax_skill_supp" => [1, 5],
    "ax_multiattack" => [1, 2], "ax_da" => [1, 2], "ax_ta" => [1, 2]
  }.freeze

  def up
    WeaponStatModifier.find_or_create_by!(slug: "ax_skill_cap") do |m|
      m.name_en = "Skill DMG Cap"
      m.name_jp = "アビダメ上限"
      m.category = "ax"
      m.stat = "skill_cap"
      m.polarity = 1
      m.suffix = "%"
      m.ax_group = "secondary"
    end

    SECONDARY_RANGES.each do |slug, (min, max)|
      WeaponStatModifier.find_by(slug: slug)&.update!(secondary_min: min, secondary_max: max)
    end
    POOLS.each do |slug, pools|
      WeaponStatModifier.find_by(slug: slug)&.update!(ax_secondaries: pools)
    end
  end

  def down
    WeaponStatModifier.update_all(secondary_min: nil, secondary_max: nil, ax_secondaries: {})
  end
end
