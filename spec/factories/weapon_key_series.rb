# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_key_series, class: 'WeaponKeySeries' do
    association :weapon_key
    association :weapon_series
  end
end
