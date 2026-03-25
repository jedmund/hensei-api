FactoryBot.define do
  factory :weapon do
    sequence(:granblue_id) { |n| "104#{n.to_s.rjust(7, '0')}" }
    sequence(:name_en) { |n| "Test Weapon #{n}" }
    name_jp { "テスト武器" }
    rarity { 4 } # SSR
    element { 1 } # Fire
    proficiency { 1 } # Sabre
    series { 99 } # Gacha (legacy)

    # Use weapon_series association if available
    weapon_series { nil }

    # Release info
    release_date { 1.year.ago }
    flb_date { 6.months.ago }
    ulb_date { nil }
    transcendence_date { nil }

    # Max stats
    max_hp { 300 }
    max_atk { 2400 }
    max_hp_flb { 360 }
    max_atk_flb { 2900 }
    max_hp_ulb { nil }
    max_atk_ulb { nil }

    # Capabilities
    flb { true }
    ulb { false }
    transcendence { false }
    # Skill info
    max_skill_level { 15 }
    max_level { 150 }

    trait :r do
      rarity { 2 }
      max_hp { 120 }
      max_atk { 960 }
      max_hp_flb { nil }
      max_atk_flb { nil }
      flb { false }
    end

    trait :sr do
      rarity { 3 }
      max_hp { 200 }
      max_atk { 1600 }
      max_hp_flb { 240 }
      max_atk_flb { 1920 }
    end

    trait :ssr do
      rarity { 4 }
    end

    trait :transcendable do
      ulb { true }
      transcendence { true }
      ulb_date { 3.months.ago }
      transcendence_date { 1.month.ago }
      max_hp_ulb { 420 }
      max_atk_ulb { 3400 }
      max_level { 200 }
      max_skill_level { 20 }
    end

    trait :opus do
      series { 3 } # dark-opus (legacy)
      weapon_series { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus) }
    end

    trait :draconic do
      series { 27 } # draconic (legacy)
      weapon_series { WeaponSeries.find_by(slug: 'draconic') || create(:weapon_series, :draconic) }
    end

    trait :revenant do
      series { 4 } # revenant (legacy)
      weapon_series { WeaponSeries.find_by(slug: 'revenant') || create(:weapon_series, :revenant) }
    end

    trait :odiant do
      weapon_series { WeaponSeries.find_by(slug: 'odiant') || create(:weapon_series, :odiant) }
      max_exorcism_level { 5 }
    end

    trait :with_befoulment do
      weapon_series { WeaponSeries.find_by(slug: 'odiant') || create(:weapon_series, :odiant) }
      max_exorcism_level { 5 }
    end
  end
end