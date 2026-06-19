# frozen_string_literal: true

FactoryBot.define do
  factory :character_skill_version_link do
    association :from_version, factory: :character_skill_version
    association :to_version, factory: :character_skill_version
    relation { :transforms_to }

    trait :option_of do
      relation { :option_of }
    end

    trait :form_counterpart do
      relation { :form_counterpart }
    end
  end
end
