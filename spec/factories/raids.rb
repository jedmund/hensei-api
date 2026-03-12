# frozen_string_literal: true

FactoryBot.define do
  factory :raid do
    association :group, factory: :raid_group
    sequence(:name_en) { |n| "Test Raid #{n}" }
    name_jp { "テストレイド" }
    sequence(:slug) { |n| "test-raid-#{n}" }
    element { 2 } # Fire (Wind=1, Fire=2, Water=3, Earth=4, Dark=5, Light=6)
    player_count { 18 }
    level { 150 }

    trait :fire do
      element { 2 }
    end

    trait :water do
      element { 3 }
    end

    trait :earth do
      element { 4 }
    end

    trait :wind do
      element { 1 }
    end

    trait :light do
      element { 6 }
    end

    trait :dark do
      element { 5 }
    end

    trait :null_element do
      element { 0 }
    end
  end
end
