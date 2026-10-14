# frozen_string_literal: true

FactoryBot.define do
  factory :arcarum_blessing do
    sequence(:slug) { |n| "blessing_#{('a'.ord + (n % 26)).chr}#{n.to_s.tr('0-9', 'a-j')}" }
    sequence(:arcana_number) { |n| 100 + n }
    sequence(:name_en) { |n| "Blessing #{n}" }
    name_jp { nil }
    released { true }

    trait :unreleased do
      released { false }
    end

    # The two blessings with rules attached; reused if they already exist.
    trait :justice do
      slug { ArcarumBlessing::JUSTICE }
      arcana_number { 11 }
      name_en { 'Justice' }
      initialize_with { ArcarumBlessing.find_or_initialize_by(slug: slug) }
    end

    trait :hanged_man do
      slug { ArcarumBlessing::HANGED_MAN }
      arcana_number { 12 }
      name_en { 'The Hanged Man' }
      initialize_with { ArcarumBlessing.find_or_initialize_by(slug: slug) }
    end
  end

  factory :arcarum_blessing_level do
    association :arcarum_blessing
    sequence(:level) { |n| n }
    description_en { 'Effect' }
    description_jp { nil }
    cost { 50 }
    scintillas { 1000 }
  end

  factory :party_blessing do
    association :party, :solomonis
    association :arcarum_blessing_level
  end
end
