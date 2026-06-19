# frozen_string_literal: true

FactoryBot.define do
  factory :character_skill do
    association :character
    kind { :ability }
    sequence(:position) { |n| n }
    game_action_id { nil }

    after(:build) do |character_skill|
      character_skill.character_granblue_id = character_skill.character.granblue_id
    end

    trait :ougi do
      kind { :ougi }
      position { 1 }
    end

    trait :support do
      kind { :support }
    end
  end
end
