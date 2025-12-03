FactoryBot.define do
  factory :collection_weapon do
    association :user
    association :weapon
    uncap_level { 3 }
    transcendence_step { 0 }
    awakening { nil }
    awakening_level { 1 }
    element { nil } # Only used for element-changeable weapons

    # AX skills
    ax_modifier1 { nil }
    ax_strength1 { nil }
    ax_modifier2 { nil }
    ax_strength2 { nil }

    # Weapon keys
    weapon_key1 { nil }
    weapon_key2 { nil }
    weapon_key3 { nil }
    weapon_key4 { nil }

    # Trait for max uncap
    trait :max_uncap do
      uncap_level { 5 }
    end

    # Trait for transcended weapon
    trait :transcended do
      uncap_level { 5 }
      transcendence_step { 5 }
      after(:build) do |collection_weapon|
        collection_weapon.weapon = FactoryBot.create(:weapon, :transcendable)
      end
    end

    # Trait for max transcendence
    trait :max_transcended do
      uncap_level { 5 }
      transcendence_step { 10 }
      after(:build) do |collection_weapon|
        collection_weapon.weapon = FactoryBot.create(:weapon, :transcendable)
      end
    end

    # Trait for weapon with awakening
    trait :with_awakening do
      after(:build) do |collection_weapon|
        collection_weapon.awakening = Awakening.where(object_type: 'Weapon').first ||
                                     FactoryBot.create(:awakening, object_type: 'Weapon')
        collection_weapon.awakening_level = 5
      end
    end

    # Trait for weapon with keys
    trait :with_keys do
      after(:build) do |collection_weapon|
        # Use an Opus weapon since it supports keys
        collection_weapon.weapon = FactoryBot.create(:weapon, :opus)
        # Create weapon keys that are compatible with Opus weapons
        collection_weapon.weapon_key1 = FactoryBot.create(:weapon_key, :opus_key)
        collection_weapon.weapon_key2 = FactoryBot.create(:weapon_key, :opus_key)
        collection_weapon.weapon_key3 = FactoryBot.create(:weapon_key, :opus_key)
      end
    end

    # Trait for weapon with all 4 keys (Opus/Draconics)
    trait :with_four_keys do
      with_keys
      after(:build) do |collection_weapon|
        # Opus weapon is already set by :with_keys trait
        collection_weapon.weapon_key4 = FactoryBot.create(:weapon_key, :opus_key)
      end
    end

    # Trait for AX weapon with skills
    trait :with_ax do
      ax_modifier1 { 1 } # Attack modifier
      ax_strength1 { 3.5 }
      ax_modifier2 { 2 } # HP modifier
      ax_strength2 { 10.0 }
    end

    # Trait for element-changed weapon (Revans weapons)
    trait :element_changed do
      element { rand(0..5) } # Random element 0-5
    end

    # Trait for fully upgraded weapon
    trait :maxed do
      uncap_level { 5 }
      transcendence_step { 10 }
      after(:build) do |collection_weapon|
        # Create a transcendable Opus weapon for full key support
        opus_series = WeaponSeries.find_by(slug: 'dark-opus') || FactoryBot.create(:weapon_series, :opus)
        collection_weapon.weapon = FactoryBot.create(:weapon, :transcendable, weapon_series: opus_series)
        collection_weapon.awakening = Awakening.where(object_type: 'Weapon').first ||
                                     FactoryBot.create(:awakening, object_type: 'Weapon')
        collection_weapon.awakening_level = 10
        # Create keys compatible with Opus weapons
        collection_weapon.weapon_key1 = FactoryBot.create(:weapon_key, :opus_key)
        collection_weapon.weapon_key2 = FactoryBot.create(:weapon_key, :opus_key)
        collection_weapon.weapon_key3 = FactoryBot.create(:weapon_key, :opus_key)
      end
    end
  end
end