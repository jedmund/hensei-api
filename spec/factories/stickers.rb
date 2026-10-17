# frozen_string_literal: true

FactoryBot.define do
  factory :sticker do
    sequence(:slug) { |n| "sticker-#{n}" }
    meaning_en { 'Cleared with this: it works' }
    meaning_jp { 'これでクリアできた' }
    sequence(:position) { |n| n }
    active { true }

    trait :inactive do
      active { false }
    end
  end

  factory :party_sticker do
    association :user
    association :party
    association :sticker
  end
end
