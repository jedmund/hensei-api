# frozen_string_literal: true

FactoryBot.define do
  factory :skill_effect do
    association :character_skill_version
    association :status
    sequence(:ordinal) { |n| n }
    effect_type { :grant_status }
    target { :caster }
    amount { nil }
    amount_max { nil }
    duration_value { nil }
    duration_unit { nil }
    accuracy { nil }
    stacking_frame { nil }
    damage_pct { nil }
    hit_count { nil }
    damage_cap { nil }
    damage_element { nil }
    heal_pct { nil }
    heal_cap { nil }
    raw { nil }

    trait :damage do
      status { nil }
      effect_type { :deal_damage }
      target { :one_foe }
      damage_pct { 450.0 }
      hit_count { 1 }
      damage_cap { 1_000_000 }
      damage_element { 'earth' }
    end

    trait :heal do
      status { nil }
      effect_type { :heal }
      target { :all_allies }
      heal_pct { 10.0 }
      heal_cap { 2020 }
    end
  end
end
