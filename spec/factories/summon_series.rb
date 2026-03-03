# frozen_string_literal: true

FactoryBot.define do
  factory :summon_series do
    sequence(:name_en) { |n| "Test Summon Series #{n}" }
    sequence(:name_jp) { |n| "テスト召喚シリーズ#{n}" }
    sequence(:slug) { |n| "test-summon-series-#{n}" }
    sequence(:order) { |n| n + 100 }

    trait :providence do
      slug { 'providence' }
      name_en { 'Providence' }
      name_jp { 'プロビデンス' }
      order { 1 }
    end

    trait :genesis do
      slug { 'genesis' }
      name_en { 'Genesis' }
      name_jp { 'ジェネシス' }
      order { 2 }
    end

    trait :magna do
      slug { 'magna' }
      name_en { 'Magna' }
      name_jp { 'マグナ' }
      order { 3 }
    end

    trait :optimus do
      slug { 'optimus' }
      name_en { 'Optimus' }
      name_jp { 'オプティマス' }
      order { 4 }
    end

    trait :arcarum do
      slug { 'arcarum' }
      name_en { 'Arcarum' }
      name_jp { 'アーカルム' }
      order { 5 }
    end
  end
end
