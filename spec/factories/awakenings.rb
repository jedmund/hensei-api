FactoryBot.define do
  factory :awakening do
    sequence(:name_en) { |n| "Awakening #{n}" }
    name_jp { "覚醒" }
    object_type { "Character" }
    sequence(:slug) { |n| "awakening-#{n}" }
    order { 1 }

    trait :for_character do
      object_type { "Character" }
    end

    trait :for_weapon do
      object_type { "Weapon" }
    end

    trait :for_summon do
      object_type { "Summon" }
    end
  end
end