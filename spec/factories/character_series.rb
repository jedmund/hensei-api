# frozen_string_literal: true

FactoryBot.define do
  factory :character_series do
    sequence(:name_en) { |n| "Test Character Series #{n}" }
    sequence(:name_jp) { |n| "テストキャラシリーズ#{n}" }
    sequence(:slug) { |n| "test-character-series-#{n}" }
    sequence(:order) { |n| n + 100 }

    trait :grand do
      slug { 'grand' }
      name_en { 'Grand' }
      name_jp { 'リミテッド' }
      order { 1 }
    end

    trait :zodiac do
      slug { 'zodiac' }
      name_en { 'Zodiac' }
      name_jp { '十二神将' }
      order { 2 }
    end

    trait :eternal do
      slug { 'eternal' }
      name_en { 'Eternal' }
      name_jp { '十天衆' }
      order { 3 }
    end

    trait :evoker do
      slug { 'evoker' }
      name_en { 'Evoker' }
      name_jp { '賢者' }
      order { 4 }
    end

    trait :saint do
      slug { 'saint' }
      name_en { 'Saint' }
      name_jp { '聖人' }
      order { 5 }
    end
  end
end
