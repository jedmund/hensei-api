# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_awakening do
    weapon
    awakening factory: %i[awakening for_weapon]
  end
end
