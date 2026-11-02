# frozen_string_literal: true

FactoryBot.define do
  factory :bullet do
    # Real ids start with the type (1-4); 9xxxx can't collide with them
    sequence(:granblue_id) { |n| format('9%04d', n % 10_000) }
    sequence(:name_en) { |n| "Test Bullet #{n}" }
    name_jp { 'テストバレット' }
    sequence(:slug) { |n| "test-bullet-#{n}" }
    bullet_type { 1 }
    atk { 100 }
    hits_all { false }
    sequence(:order) { |n| n }
  end
end
