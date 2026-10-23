# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_skill_version do
    association :weapon_skill
    association :skill, factory: :skill, skill_type: :weapon
    sequence(:ordinal) { |n| n }
    min_uncap { 3 }
    transcendence_stage { 0 }
    skill_modifier { nil }
    skill_series { nil }
    skill_size { nil }

    trait :flb do
      unlock_level { 150 }
      min_uncap { 4 }
    end

    trait :ulb do
      unlock_level { 200 }
      min_uncap { 5 }
    end

    trait :transcendence do
      unlock_level { 210 }
      min_uncap { 5 }
      transcendence_stage { 1 }
    end

    trait :normal_might_big do
      skill_modifier { 'Might' }
      skill_series { :normal }
      skill_size { :big }
      scales_with_skill_level { true }
    end
  end
end
