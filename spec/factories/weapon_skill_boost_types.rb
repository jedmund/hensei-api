# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_skill_boost_type do
    sequence(:key) { |n| "boost_type_#{n}" }
    sequence(:name_en) { |n| "Test Boost Type #{n}" }
    name_jp { nil }
    category { 'offensive' }
    stacking_rule { 'additive' }
    grid_cap { nil }
    cap_is_flat { false }
    notes { nil }

    trait :offensive do
      category { 'offensive' }
    end

    trait :defensive do
      category { 'defensive' }
    end

    trait :multiattack do
      category { 'multiattack' }
    end

    trait :cap do
      category { 'cap' }
    end

    trait :supplemental do
      category { 'supplemental' }
    end

    trait :utility do
      category { 'utility' }
    end

    trait :with_cap do
      grid_cap { 30.0 }
    end

    trait :flat_cap do
      grid_cap { 5000.0 }
      cap_is_flat { true }
    end

    trait :multiplicative do
      stacking_rule { 'multiplicative_by_series' }
    end

    trait :highest_only do
      stacking_rule { 'highest_only' }
    end
  end
end
