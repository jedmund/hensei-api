# frozen_string_literal: true

FactoryBot.define do
  factory :party do
    association :user

    # Use a sequence for unique party names (optional).
    sequence(:name) { |n| "Party #{n}" }
    description { Faker::Lorem.sentence }
    extra { false }
    full_auto { false }
    auto_guard { false }
    charge_attack { true }
    clear_time { 0 }
    button_count { 0 }
    chain_count { 0 }
    turn_count { 0 }
    visibility { 1 }
    # Note: Shortcode and edit_key will be auto-generated via before_create callbacks.
  end
end
