# frozen_string_literal: true

FactoryBot.define do
  factory :collection_artifact do
    association :user
    association :artifact
    element { 'fire' }
    level { 1 }
    proficiency { nil }
    nickname { nil }
    # Default to empty skills to avoid validation issues without seeded data
    skill1 { {} }
    skill2 { {} }
    skill3 { {} }
    skill4 { {} }

    trait :with_skills do
      # Use this trait after seeding artifact skills in your test
      skill1 { { 'modifier' => 1, 'quality' => 5, 'level' => 1 } }
      skill2 { { 'modifier' => 2, 'quality' => 5, 'level' => 1 } }
      skill3 { { 'modifier' => 1, 'quality' => 5, 'level' => 1 } }
      skill4 { { 'modifier' => 1, 'quality' => 5, 'level' => 1 } }
    end

    trait :max_level do
      level { 5 }
      skill1 { { 'modifier' => 1, 'quality' => 5, 'level' => 2 } }
      skill2 { { 'modifier' => 2, 'quality' => 5, 'level' => 2 } }
      skill3 { { 'modifier' => 1, 'quality' => 5, 'level' => 2 } }
      skill4 { { 'modifier' => 1, 'quality' => 5, 'level' => 2 } }
    end

    trait :quirk do
      association :artifact, factory: [:artifact, :quirk]
      proficiency { :sabre }
      level { 1 }
      skill1 { {} }
      skill2 { {} }
      skill3 { {} }
      skill4 { {} }
    end

    trait :with_nickname do
      nickname { 'My Favorite Artifact' }
    end

    trait :water do
      element { 'water' }
    end

    trait :earth do
      element { 'earth' }
    end

    trait :wind do
      element { 'wind' }
    end

    trait :light do
      element { 'light' }
    end

    trait :dark do
      element { 'dark' }
    end
  end
end
