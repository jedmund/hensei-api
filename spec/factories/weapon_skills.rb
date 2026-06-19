# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_skill do
    association :weapon
    sequence(:position) { |n| n }

    after(:build) do |ws|
      ws.weapon_granblue_id = ws.weapon.granblue_id
    end
  end
end
