# frozen_string_literal: true

FactoryBot.define do
  factory :party do
    association :user

    # Use a sequence for unique party names (optional).
    sequence(:name) { |n| "Party #{n}" }
    sequence(:description) { |n| "Test party description #{n}" }
    extra { false }
    full_auto { false }
    solo { false }
    auto_guard { false }
    charge_attack { true }
    clear_time { 0 }
    button_count { 0 }
    chain_count { 0 }
    turn_count { 0 }
    visibility { 1 }
    # Note: Shortcode and edit_key will be auto-generated via before_create callbacks.

    # Evoking Solomonis parties. The route Evoker sets the raid (zone) and element.
    #   create(:party, :solomonis_build)
    #   create(:party, :solomonis_run, route_evoker: nier)
    transient do
      route_evoker { nil }
    end

    trait :solomonis_build do
      after(:build) do |party, ctx|
        evoker = ctx.route_evoker || FactoryBot.create(:character, :solomonis_evoker)
        party.assign_solomonis_route(evoker, kind: 'build')
      end
    end

    trait :solomonis_run do
      after(:build) do |party, ctx|
        evoker = ctx.route_evoker || FactoryBot.create(:character, :solomonis_evoker)
        party.assign_solomonis_route(evoker, kind: 'run')
      end
    end
  end
end
