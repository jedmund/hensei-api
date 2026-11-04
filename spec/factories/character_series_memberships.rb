# frozen_string_literal: true

FactoryBot.define do
  factory :character_series_membership do
    character
    character_series
  end
end
