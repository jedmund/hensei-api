# frozen_string_literal: true

FactoryBot.define do
  factory :artifact do
    # Eleven digits, so these never match the shorter ids specs set explicitly
    sequence(:granblue_id) { |n| "9#{n.to_s.rjust(10, '0')}" }
    sequence(:name_en) { |n| "Test Artifact #{n}" }
    name_jp { 'テストアーティファクト' }
    proficiency { :sabre }
    rarity { :standard }
    release_date { Date.new(2025, 3, 10) }

    trait :quirk do
      rarity { :quirk }
      proficiency { nil }
      sequence(:granblue_id) { |n| "8#{n.to_s.rjust(10, '0')}" }
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
