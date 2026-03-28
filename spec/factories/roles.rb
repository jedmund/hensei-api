# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    name_en { 'Attacker' }
    slot_type { 'Character' }

    trait :weapon do
      name_en { 'Main DPS' }
      slot_type { 'Weapon' }
    end

    trait :summon do
      name_en { 'Stat Stick' }
      slot_type { 'Summon' }
    end
  end
end
