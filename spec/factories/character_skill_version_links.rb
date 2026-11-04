# frozen_string_literal: true

FactoryBot.define do
  factory :character_skill_version_link do
    from_version factory: %i[character_skill_version]
    to_version factory: %i[character_skill_version]
    relation { :transforms_to }

    trait :option_of do
      relation { :option_of }
    end

    trait :form_counterpart do
      relation { :form_counterpart }
    end
  end
end
