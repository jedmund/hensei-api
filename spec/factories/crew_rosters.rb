# frozen_string_literal: true

FactoryBot.define do
  factory :crew_roster do
    crew
    association :created_by, factory: :user
    name { "Fire" }
    element { 1 }
    items { [] }

    trait :fire do
      name { "Fire" }
      element { 1 }
    end

    trait :water do
      name { "Water" }
      element { 2 }
    end

    trait :with_items do
      transient do
        characters { [] }
        weapons { [] }
        summons { [] }
      end

      after(:build) do |roster, evaluator|
        roster.items = evaluator.characters.map { |c| { 'id' => c.id, 'type' => 'Character' } } +
                       evaluator.weapons.map { |w| { 'id' => w.id, 'type' => 'Weapon' } } +
                       evaluator.summons.map { |s| { 'id' => s.id, 'type' => 'Summon' } }
      end
    end
  end
end
