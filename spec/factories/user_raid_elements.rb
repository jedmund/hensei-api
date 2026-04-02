# frozen_string_literal: true

FactoryBot.define do
  factory :user_raid_element do
    association :user
    association :raid
    element { Faker::Number.between(from: 1, to: 6) }
  end
end
