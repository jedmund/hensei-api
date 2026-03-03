# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_awakening do
    association :weapon
    association :awakening, :for_weapon
  end
end
