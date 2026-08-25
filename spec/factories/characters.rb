FactoryBot.define do
  factory :character do
    sequence(:granblue_id) { |n| "304#{n.to_s.rjust(7, '0')}" }
    sequence(:name_en) { |n| "Test Character #{n}" }
    name_jp { "テストキャラクター" }
    rarity { 4 } # SSR
    element { 1 } # Fire
    race1 { 1 } # Human
    race2 { nil }
    gender { 0 } # Unknown

    proficiency1 { 1 } # Sabre
    proficiency2 { nil }

    # Max stats
    max_hp { 1500 }
    max_atk { 8000 }
    max_hp_flb { 1800 }
    max_atk_flb { 9600 }
    max_hp_ulb { nil }
    max_atk_ulb { nil }
    max_hp_transcendence { nil }
    max_atk_transcendence { nil }

    # FLB and transcendence capabilities
    flb { true }
    ulb { false }
    transcendence { false }
    max_transcendence_stage { 0 }

    release_date { 1.year.ago }

    trait :r do
      rarity { 2 }
      max_hp { 800 }
      max_atk { 4000 }
    end

    trait :sr do
      rarity { 3 }
      max_hp { 1200 }
      max_atk { 6000 }
    end

    trait :ssr do
      rarity { 4 }
    end

    trait :transcendable do
      transcendence { true }
      max_transcendence_stage { 5 }
      max_hp_transcendence { 2100 }
      max_atk_transcendence { 11200 }
    end

    trait :special_ulb do
      rarity { 3 }
      special { true }
      flb { true }
      ulb { true }
      max_hp_ulb { 1900 }
      max_atk_ulb { 10_000 }
    end
  end
end
