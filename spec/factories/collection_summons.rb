FactoryBot.define do
  factory :collection_summon do
    association :user
    association :summon
    uncap_level { 3 }
    transcendence_step { 0 }

    # Trait for max uncap
    trait :max_uncap do
      uncap_level { 5 }
    end

    # Trait for transcended summon
    trait :transcended do
      uncap_level { 5 }
      transcendence_step { 5 }
      after(:build) do |collection_summon|
        collection_summon.summon = FactoryBot.create(:summon, :transcendable)
      end
    end

    # Trait for max transcendence
    trait :max_transcended do
      uncap_level { 5 }
      transcendence_step { 10 }
      after(:build) do |collection_summon|
        collection_summon.summon = FactoryBot.create(:summon, :transcendable)
      end
    end

    # Trait for 0* summon (common for gacha summons)
    trait :no_uncap do
      uncap_level { 0 }
    end

    # Trait for 1* summon
    trait :one_star do
      uncap_level { 1 }
    end

    # Trait for 2* summon
    trait :two_star do
      uncap_level { 2 }
    end

    # Trait for 3* summon (common stopping point)
    trait :three_star do
      uncap_level { 3 }
    end

    # Trait for 4* summon (FLB)
    trait :four_star do
      uncap_level { 4 }
    end

    # Trait for 5* summon (ULB)
    trait :five_star do
      uncap_level { 5 }
    end

    # Trait for fully upgraded summon
    trait :maxed do
      uncap_level { 5 }
      transcendence_step { 10 }
      after(:build) do |collection_summon|
        collection_summon.summon = FactoryBot.create(:summon, :transcendable)
      end
    end
  end
end