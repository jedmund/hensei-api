# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_series_variant do
    association :weapon_series

    trait :ccw_replica do
      has_weapon_keys { true }
      has_awakening { false }
      element_changeable { true }
    end

    trait :ccw_forge do
      has_weapon_keys { false }
      has_awakening { true }
      element_changeable { true }
    end

    trait :override_no_keys do
      has_weapon_keys { false }
    end

    trait :override_with_awakening do
      has_awakening { true }
    end
  end
end
