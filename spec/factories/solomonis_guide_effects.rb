# frozen_string_literal: true

FactoryBot.define do
  factory :solomonis_guide_effect do
    sequence(:granblue_id) { |n| 1000 + n }
    rarity { 'normal' }
    stackable { true }
    sequence(:name_en) { |n| "ATK +#{n}%" }
    name_jp { nil }
    icon_category { 1 }
    icon_type { 1 }
    target_type { nil }
    target_values { [] }
    availability { 'global' }
    type_tags { nil }
    effect_tags { nil }

    trait :unique do
      rarity { 'unique' }
      stackable { false }
    end

    trait :cursed do
      rarity { 'cursed' }
    end
  end

  factory :expedition_guide_effect do
    association :party, :solomonis_run
    association :solomonis_guide_effect
    count { 1 }
    inherited { false }
  end
end
