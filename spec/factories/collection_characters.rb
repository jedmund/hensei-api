FactoryBot.define do
  factory :collection_character do
    association :user
    # Use the first character from canonical data or create one
    character { Character.first || association(:character) }
    uncap_level { 3 }
    transcendence_step { 0 }
    perpetuity { false }
    awakening { nil }
    awakening_level { 1 }

    # Ring data with default nil values
    ring1 { { modifier: nil, strength: nil } }
    ring2 { { modifier: nil, strength: nil } }
    ring3 { { modifier: nil, strength: nil } }
    ring4 { { modifier: nil, strength: nil } }
    earring { { modifier: nil, strength: nil } }

    # Trait for a fully uncapped character
    trait :max_uncap do
      uncap_level { 5 }
    end

    # Trait for a transcended character (requires max uncap)
    trait :transcended do
      uncap_level { 5 }
      transcendence_step { 5 }
    end

    # Trait for max transcendence
    trait :max_transcended do
      uncap_level { 5 }
      transcendence_step { 10 }
    end

    # Trait for a character with awakening
    trait :with_awakening do
      after(:build) do |collection_character|
        # Create a character awakening if none exists
        collection_character.awakening = Awakening.where(object_type: 'Character').first ||
                                        FactoryBot.create(:awakening, object_type: 'Character')
        collection_character.awakening_level = 5
      end
    end

    # Trait for max awakening
    trait :max_awakening do
      after(:build) do |collection_character|
        collection_character.awakening = Awakening.where(object_type: 'Character').first ||
                                        FactoryBot.create(:awakening, object_type: 'Character')
        collection_character.awakening_level = 10
      end
    end

    # Trait for a character with rings
    trait :with_rings do
      ring1 { { modifier: 1, strength: 10.5 } }
      ring2 { { modifier: 2, strength: 8.0 } }
      ring3 { { modifier: 3, strength: 15.0 } }
      ring4 { { modifier: 4, strength: 12.5 } }
    end

    # Trait for a character with earring
    trait :with_earring do
      earring { { modifier: 5, strength: 20.0 } }
    end

    # Trait for a fully maxed character
    trait :maxed do
      uncap_level { 5 }
      transcendence_step { 10 }
      perpetuity { true }
      max_awakening
      with_rings
      with_earring
    end
  end
end