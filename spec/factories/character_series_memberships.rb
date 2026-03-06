# frozen_string_literal: true

FactoryBot.define do
  factory :character_series_membership do
    association :character
    association :character_series
  end
end
