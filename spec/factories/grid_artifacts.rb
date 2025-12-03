# frozen_string_literal: true

FactoryBot.define do
  factory :grid_artifact do
    association :grid_character
    association :artifact
    # Default to light to match the canonical character (Rosamia SSR, element 6/light)
    element { 'light' }
    level { 1 }
    proficiency { nil }
    # Default to empty skills to avoid validation issues without seeded data
    skill1 { {} }
    skill2 { {} }
    skill3 { {} }
    skill4 { {} }

    trait :with_skills do
      # Use this trait after seeding artifact skills in your test
      skill1 { { 'modifier' => 1, 'strength' => 1800, 'level' => 1 } }
      skill2 { { 'modifier' => 2, 'strength' => 900, 'level' => 1 } }
      skill3 { { 'modifier' => 1, 'strength' => 18.0, 'level' => 1 } }
      skill4 { { 'modifier' => 1, 'strength' => 10, 'level' => 1 } }
    end

    trait :max_level do
      level { 5 }
      skill1 { { 'modifier' => 1, 'strength' => 1800, 'level' => 2 } }
      skill2 { { 'modifier' => 2, 'strength' => 900, 'level' => 2 } }
      skill3 { { 'modifier' => 1, 'strength' => 18.0, 'level' => 2 } }
      skill4 { { 'modifier' => 1, 'strength' => 10, 'level' => 2 } }
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
  end
end
