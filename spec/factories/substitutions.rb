# frozen_string_literal: true

FactoryBot.define do
  factory :substitution do
    grid factory: %i[grid_weapon]
    substitute_grid factory: %i[grid_weapon]
    position { 0 }
  end
end
