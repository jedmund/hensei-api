# frozen_string_literal: true

FactoryBot.define do
  factory :summon_aura do
    sequence(:summon_granblue_id) { |n| (2_040_000_000 + n).to_s }
    slot { 'main' }
    target { 'other' }
    value { 50 }
    uncap_level { 0 }
    transcendence_stage { 0 }
  end
end
