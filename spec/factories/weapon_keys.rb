FactoryBot.define do
  factory :weapon_key do
    sequence(:name_en) { |n| "Pendulum of #{['Strife', 'Sagacity', 'Prosperity', 'Forbiddance', 'Temperament'].sample}" }
    name_jp { "鍵" }
    slot { rand(1..3) }
    group { rand(1..5) }
    order { rand(1..20) }
    sequence(:slug) { |n| "key-#{n}" }
    sequence(:granblue_id) { |n| n.to_s }
    series { [3, 27] } # Opus and Draconic weapons (legacy)

    trait :opus_key do
      series { [3] }
      after(:create) do |weapon_key|
        opus_series = WeaponSeries.find_by(slug: 'dark-opus') || FactoryBot.create(:weapon_series, :opus)
        weapon_key.weapon_series << opus_series unless weapon_key.weapon_series.include?(opus_series)
      end
    end

    trait :draconic_key do
      series { [27] }
      after(:create) do |weapon_key|
        draconic_series = WeaponSeries.find_by(slug: 'draconic') || FactoryBot.create(:weapon_series, :draconic)
        weapon_key.weapon_series << draconic_series unless weapon_key.weapon_series.include?(draconic_series)
      end
    end

    trait :universal_key do
      series { [3, 27, 99] } # Works with more weapon series (legacy)
      after(:create) do |weapon_key|
        opus_series = WeaponSeries.find_by(slug: 'dark-opus') || FactoryBot.create(:weapon_series, :opus)
        draconic_series = WeaponSeries.find_by(slug: 'draconic') || FactoryBot.create(:weapon_series, :draconic)
        gacha_series = WeaponSeries.find_by(slug: 'gacha') || FactoryBot.create(:weapon_series, :gacha)

        [opus_series, draconic_series, gacha_series].each do |ws|
          weapon_key.weapon_series << ws unless weapon_key.weapon_series.include?(ws)
        end
      end
    end
  end
end