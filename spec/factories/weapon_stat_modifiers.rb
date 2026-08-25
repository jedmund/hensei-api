# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_stat_modifier do
    sequence(:slug) { |n| "ax-modifier-#{n}" }
    sequence(:name_en) { |n| "AX Modifier #{n}" }
    category { 'ax' }
    polarity { 1 }

    trait :ax_atk do
      slug { 'ax_atk' }
      name_en { 'ATK' }
      category { 'ax' }
      stat { 'atk' }
      polarity { 1 }
      suffix { '%' }
      game_skill_id { 1589 }
      ax_group { 'primary' }
      base_min { 1 }
      base_max { 3.5 }
      secondary_min { 1 }
      secondary_max { 1.5 }
      ax_secondaries { WeaponStatModifier::AX_SECONDARY_POOLS.fetch('ax_atk') }
    end

    trait :ax_hp do
      slug { 'ax_hp' }
      name_en { 'HP' }
      category { 'ax' }
      stat { 'hp' }
      polarity { 1 }
      suffix { '%' }
      game_skill_id { 1588 }
      ax_group { 'primary' }
      base_min { 1 }
      base_max { 11 }
      secondary_min { 1 }
      secondary_max { 3 }
      ax_secondaries { WeaponStatModifier::AX_SECONDARY_POOLS.fetch('ax_hp') }
    end

    trait :ax_ca_dmg do
      slug { 'ax_ca_dmg' }
      name_en { 'C.A. DMG' }
      category { 'ax' }
      stat { 'ca_dmg' }
      polarity { 1 }
      suffix { '%' }
      game_skill_id { 1591 }
      ax_group { 'primary' }
      base_min { 2 }
      base_max { 8.5 }
      secondary_min { 2 }
      secondary_max { 4 }
      ax_secondaries { WeaponStatModifier::AX_SECONDARY_POOLS.fetch('ax_ca_dmg') }
    end

    trait :befoulment do
      sequence(:slug) { |n| "befoul-modifier-#{n}" }
      sequence(:name_en) { |n| "Befoulment #{n}" }
      category { 'befoulment' }
      polarity { -1 }
    end

    trait :befoul_def_down do
      slug { 'befoul_def_down' }
      name_en { 'DEF Down' }
      category { 'befoulment' }
      stat { 'def' }
      polarity { -1 }
      suffix { '%' }
      game_skill_id { 2880 }
    end
  end
end
