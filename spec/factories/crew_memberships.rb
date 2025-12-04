FactoryBot.define do
  factory :crew_membership do
    crew
    user
    role { :member }
    retired { false }

    trait :captain do
      role { :captain }
    end

    trait :vice_captain do
      role { :vice_captain }
    end

    trait :retired do
      retired { true }
      retired_at { Time.current }
    end
  end
end
