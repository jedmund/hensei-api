# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    sequence(:name_en) { |n| "Role #{n}" }
    slot_type { 'Character' }
    sort_order { 0 }
  end
end
