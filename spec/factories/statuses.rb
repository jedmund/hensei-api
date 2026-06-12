# frozen_string_literal: true

FactoryBot.define do
  factory :status do
    sequence(:game_ailment_id) { |n| "ailment-#{n}" }
    sequence(:name_en) { |n| "Status #{n}" }
    name_jp { nil }
    family { nil }
    level { nil }
    category { :buff }
    icon { nil }
    wiki_slug { nil }

    trait :debuff do
      category { :debuff }
    end

    trait :field do
      category { :field }
    end

    trait :special do
      category { :special }
    end
  end
end
