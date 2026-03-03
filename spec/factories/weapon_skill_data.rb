# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_skill_datum do
    sequence(:modifier) { |n| "TestMod#{n}" }
    boost_type { 'atk' }
    series { 'normal' }
    size { 'big' }
    formula_type { 'flat' }
    sl1 { 1.0 }
    sl10 { 10.0 }
    sl15 { 15.0 }
    aura_boostable { true }

    trait :normal_omega do
      series { 'normal_omega' }
    end

    trait :omega do
      series { 'omega' }
    end

    trait :ex do
      series { 'ex' }
    end

    trait :odious do
      series { 'odious' }
    end

    trait :no_series do
      series { nil }
    end

    trait :enmity do
      formula_type { 'enmity' }
    end

    trait :stamina do
      formula_type { 'stamina' }
    end
  end
end
