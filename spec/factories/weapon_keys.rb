FactoryBot.define do
  factory :weapon_key do
    sequence(:name_en) { |n| "Pendulum of #{['Strife', 'Sagacity', 'Prosperity', 'Forbiddance', 'Temperament'].sample}" }
    name_jp { "鍵" }
    slot { rand(1..3) }
    group { rand(1..5) }
    order { rand(1..20) }
    sequence(:slug) { |n| "key-#{n}" }
    sequence(:granblue_id) { |n| n.to_s }
    series { [3, 27] } # Opus and Draconic weapons

    trait :opus_key do
      series { [3] }
    end

    trait :draconic_key do
      series { [27] }
    end

    trait :universal_key do
      series { [3, 27, 99] } # Works with more weapon series
    end
  end
end