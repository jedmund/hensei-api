# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    sequence(:name_en) { |n| "Event #{n}" }
    name_jp { 'イベント' }
    kind { :story_event }
    status { :approved }
    starts_at { 2.days.ago }
    ends_at { 5.days.from_now }

    trait :draft do
      status { :draft }
    end

    trait :dread_barrage do
      kind { :dread_barrage }
      element { 'Fire' }
    end

    trait :hidden do
      status { :hidden }
    end

    trait :current do
      starts_at { 2.days.ago }
      ends_at { 5.days.from_now }
    end

    trait :upcoming do
      starts_at { 3.days.from_now }
      ends_at { 10.days.from_now }
    end

    trait :past do
      starts_at { 40.days.ago }
      ends_at { 33.days.ago }
    end

    trait :unite_and_fight do
      kind { :unite_and_fight }
      element { 'Water' }
    end
  end

  factory :event_raid do
    association :event
    association :raid
    position { 0 }
  end

  factory :featured_party do
    association :party
    event { nil }
    sequence(:position) { |n| n }
    note_en { 'A great team' }
    note_jp { '良い編成' }
  end
end
