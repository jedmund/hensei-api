# frozen_string_literal: true

FactoryBot.define do
  factory :summon_aura do
    summon_granblue_id { Faker::Number.number(digits: 10).to_s }
    slot { 'main' }
    target { 'other' }
    value { 50 }
    uncap_level { 0 }
    transcendence_stage { 0 }
  end
end
