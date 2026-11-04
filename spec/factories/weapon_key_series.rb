# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_key_series, class: 'WeaponKeySeries' do
    weapon_key
    weapon_series
  end
end
