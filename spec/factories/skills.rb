# frozen_string_literal: true

FactoryBot.define do
  factory :skill do
    sequence(:name_en) { |n| "Test Skill #{n}" }
    skill_type { :weapon }

    trait :weapon do
      skill_type { :weapon }
    end

    trait :character do
      skill_type { :character }
    end

    trait :charge_attack do
      skill_type { :charge_attack }
    end

    trait :summon do
      skill_type { :summon }
    end
  end
end
