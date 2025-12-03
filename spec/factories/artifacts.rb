# frozen_string_literal: true

FactoryBot.define do
  factory :artifact do
    # Use UUID-like sequence to ensure uniqueness across test runs
    sequence(:granblue_id) { |n| "9#{SecureRandom.hex(4)}#{n}" }
    sequence(:name_en) { |n| "Test Artifact #{n}" }
    name_jp { 'テストアーティファクト' }
    proficiency { :sabre }
    rarity { :standard }
    release_date { Date.new(2025, 3, 10) }

    trait :quirk do
      rarity { :quirk }
      proficiency { nil }
      sequence(:granblue_id) { |n| "8#{SecureRandom.hex(4)}#{n}" }
      sequence(:name_en) { |n| "Quirk Artifact #{n}" }
      name_jp { 'クィルクアーティファクト' }
    end

    trait :dagger do
      proficiency { :dagger }
    end

    trait :spear do
      proficiency { :spear }
    end

    trait :staff do
      proficiency { :staff }
    end
  end
end
