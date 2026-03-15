# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    name_en { 'Buffer' }
    slot_type { 'Character' }
    sort_order { 0 }

    trait :weapon do
      name_en { 'Main damage' }
      slot_type { 'Weapon' }
    end

    trait :summon do
      name_en { 'Stat stick' }
      slot_type { 'Summon' }
    end
  end
end
