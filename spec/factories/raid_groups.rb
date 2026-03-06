# frozen_string_literal: true

FactoryBot.define do
  factory :raid_group do
    sequence(:name_en) { |n| "Test Raid Group #{n}" }
    sequence(:name_jp) { |n| "テストレイドグループ#{n}" }
    sequence(:order) { |n| n }
    section { 1 }
    difficulty { nil }
    extra { false }
    hl { true }
    guidebooks { false }
    unlimited { false }

    trait :extra do
      extra { true }
    end

    trait :with_guidebooks do
      guidebooks { true }
    end

    trait :unlimited do
      unlimited { true }
    end

    trait :non_hl do
      hl { false }
    end
  end
end
