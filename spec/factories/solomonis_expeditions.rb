# frozen_string_literal: true

FactoryBot.define do
  # Builds the party around the expedition so its raid and element follow the
  # route Evoker. Prefer create(:party, :solomonis) when you need the party.
  factory :solomonis_expedition do
    pledge_level { 0 }
    route_evoker { association :character, :solomonis_evoker, strategy: :create }
    party { association :party, strategy: :build }

    after(:build) do |expedition|
      expedition.party.solomonis_expedition = expedition
      expedition.party.raid_id = expedition.route_evoker.solomonis_zone_id
      expedition.party.element = expedition.route_evoker.element
    end

    to_create { |expedition| expedition.party.save! }

    trait :cleared do
      outcome { 'cleared' }
      ended_at { Time.zone.parse('2026-10-11 16:38 +09:00') }
      sequence(:game_report_id) { |n| 381_000 + n }
      stats { { 'battle' => 14, 'boss' => 2, 'event' => 20, 'shop_purchases' => 18, 'points_earned' => 2924 } }
    end
  end
end
