# frozen_string_literal: true

FactoryBot.define do
  factory :gacha do
    drawable_type { 'Character' }
    drawable_id { association(:character).id }
    premium { true }
    classic { false }
    flash { false }
    legend { false }
    valentines { false }
    summer { false }
    halloween { false }
    holiday { false }
    classic_ii { false }
    collab { false }

    trait :flash do
      flash { true }
    end

    trait :legend do
      legend { true }
    end

    trait :classic do
      classic { true }
    end

    trait :classic_ii do
      classic_ii { true }
    end

    trait :seasonal_valentines do
      valentines { true }
    end

    trait :seasonal_summer do
      summer { true }
    end

    trait :seasonal_halloween do
      halloween { true }
    end

    trait :seasonal_holiday do
      holiday { true }
    end

    trait :collab do
      collab { true }
    end

    trait :for_weapon do
      drawable_type { 'Weapon' }
      drawable_id { association(:weapon).id }
    end

    trait :for_summon do
      drawable_type { 'Summon' }
      drawable_id { association(:summon).id }
    end
  end
end
