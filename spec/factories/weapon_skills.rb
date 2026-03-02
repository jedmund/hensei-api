# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_skill do
    association :weapon
    association :skill, factory: :skill, skill_type: :weapon
    sequence(:position) { |n| n }
    uncap_level { 0 }
    skill_modifier { nil }
    skill_series { nil }
    skill_size { nil }

    after(:build) do |ws|
      ws.weapon_granblue_id = ws.weapon.granblue_id
    end

    trait :normal_might_big do
      skill_modifier { 'Might' }
      skill_series { :normal }
      skill_size { :big }
    end

    trait :omega_enmity_medium do
      skill_modifier { 'Enmity' }
      skill_series { :omega }
      skill_size { :medium }
    end
  end
end
