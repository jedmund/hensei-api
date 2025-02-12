# frozen_string_literal: true

FactoryBot.define do
  factory :grid_weapon do
    # Associations: assumes that factories for :party and :weapon are defined.
    association :party
    association :weapon

    # Default attributes
    position { 0 }
    uncap_level { 3 }
    transcendence_step { 0 }
    mainhand { false }

    # Optional associations for weapon keys and awakening are left as nil by default.
  end
end
