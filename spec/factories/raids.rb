# frozen_string_literal: true

FactoryBot.define do
  factory :raid do
    association :group, factory: :raid_group
    sequence(:name_en) { |n| "Test Raid #{n}" }
    name_jp { "テストレイド" }
    sequence(:slug) { |n| "test-raid-#{n}" }
    element { 1 } # Fire
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
  end
end
