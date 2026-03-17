# frozen_string_literal: true

FactoryBot.define do
  factory :playlist do
    association :user
    sequence(:title) { |n| "Playlist #{n}" }
    description { Faker::Lorem.sentence }
    visibility { 1 }
  end

  factory :playlist_party do
    association :playlist
    association :party
  end
end
