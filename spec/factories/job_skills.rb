# frozen_string_literal: true

FactoryBot.define do
  factory :job_skill do
    association :job
    sequence(:name_en) { |n| "Test Skill #{n}" }
    name_jp { "テストスキル" }
    sequence(:slug) { |n| "test-skill-#{n}" }
    color { 1 }
    main { false }
    sub { false }
    emp { false }
    base { false }

    trait :main_skill do
      main { true }
    end

    trait :sub_skill do
      sub { true }
    end

    trait :emp_skill do
      emp { true }
    end

    trait :base_skill do
      base { true }
    end
  end
end
