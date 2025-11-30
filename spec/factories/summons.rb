FactoryBot.define do
  factory :summon do
    sequence(:granblue_id) { |n| "204#{n.to_s.rjust(7, '0')}" }
    sequence(:name_en) { |n| "Test Summon #{n}" }
    name_jp { "テスト召喚石" }
    rarity { 4 } # SSR
    element { 1 } # Fire

    # Release info
    release_date { 1.year.ago }
    flb_date { 6.months.ago }
    ulb_date { nil }
    transcendence_date { nil }

    # Max stats
    max_hp { 500 }
    max_atk { 2000 }
    max_hp_flb { 600 }
    max_atk_flb { 2400 }
    max_hp_ulb { nil }
    max_atk_ulb { nil }

    # Capabilities
    flb { true }
    ulb { false }
    transcendence { false }

    trait :r do
      rarity { 2 }
      max_hp { 200 }
      max_atk { 800 }
      max_hp_flb { nil }
      max_atk_flb { nil }
      flb { false }
    end

    trait :sr do
      rarity { 3 }
      max_hp { 350 }
      max_atk { 1400 }
    end

    trait :ssr do
      rarity { 4 }
    end

    trait :transcendable do
      ulb { true }
      transcendence { true }
      ulb_date { 3.months.ago }
      transcendence_date { 1.month.ago }
      max_hp_ulb { 700 }
      max_atk_ulb { 2800 }
      max_hp_xlb { 800 }
      max_atk_xlb { 3200 }
    end
  end
end