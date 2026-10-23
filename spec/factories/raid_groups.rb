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
    support_summon { true }

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

    trait :solomonis do
      name_en { 'Evoking Solomonis' }
      section { 3 }
      difficulty { 0 }
      content_mode { RaidGroup::SOLOMONIS }
      extra { true }
      support_summon { false }
    end
  end
end
