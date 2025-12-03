# frozen_string_literal: true

FactoryBot.define do
  factory :artifact do
    # Use high sequence numbers to avoid conflicts with seeded data
    sequence(:granblue_id) { |n| "39999#{n.to_s.rjust(4, '0')}" }
    sequence(:name_en) { |n| "Test Artifact #{n}" }
    name_jp { 'テストアーティファクト' }
    proficiency { :sabre }
    rarity { :standard }
    release_date { Date.new(2025, 3, 10) }

    trait :quirk do
      rarity { :quirk }
      proficiency { nil }
      sequence(:granblue_id) { |n| "38888#{n.to_s.rjust(4, '0')}" }
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
