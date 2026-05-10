# frozen_string_literal: true

FactoryBot.define do
  factory :grid_character_role do
    sequence(:name_en) { |n| "Role #{n}" }
    name_jp { '攻撃' }
    sequence(:sort_order) { |n| n }
  end
end
