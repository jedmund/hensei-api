# frozen_string_literal: true

FactoryBot.define do
  factory :guidebook do
    sequence(:granblue_id) { |n| "9#{n.to_s.rjust(5, '0')}" }
    sequence(:name_en) { |n| "Test Guidebook #{n}" }
    name_jp { "テスト攻略本" }
    description_en { "A test guidebook description." }
    description_jp { "テスト攻略本の説明。" }
  end
end
