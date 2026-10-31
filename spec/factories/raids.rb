# frozen_string_literal: true

FactoryBot.define do
  factory :raid do
    association :group, factory: :raid_group
    sequence(:name_en) { |n| "Test Raid #{n}" }
    name_jp { "テストレイド" }
    sequence(:slug) { |n| "test-raid-#{n}" }
    element { 1 } # Fire (Fire=1, Water=2, Earth=3, Wind=4, Light=5, Dark=6)
    player_count { 18 }
    level { 150 }

    trait :fire do
      element { 1 }
    end

    trait :water do
      element { 2 }
    end

    trait :earth do
      element { 3 }
    end

    trait :wind do
      element { 4 }
    end

    trait :light do
      element { 5 }
    end

    trait :dark do
      element { 6 }
    end

    trait :null_element do
      element { 0 }
    end

    # Crew members can record element coverage for it.
    trait :trackable do
      trackable { true }
    end

    # An Evoking Solomonis zone.
    trait :solomonis_zone do
      association :group, factory: %i[raid_group solomonis]
      sequence(:name_en) { |n| "Test Microcosm #{n}" }
      name_jp { nil }
      sequence(:slug) { |n| "test-microcosm-#{n}" }
      element { 0 }
      player_count { 1 }
      level { nil }
    end
  end
end
