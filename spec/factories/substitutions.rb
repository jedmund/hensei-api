# frozen_string_literal: true

FactoryBot.define do
  factory :substitution do
    association :grid, factory: :grid_weapon
    association :substitute_grid, factory: :grid_weapon
    position { 0 }
  end
end
