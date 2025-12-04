FactoryBot.define do
  factory :crew_invitation do
    crew
    user
    association :invited_by, factory: :user
    status { :pending }
    expires_at { 7.days.from_now }

    trait :accepted do
      status { :accepted }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :expired do
      status { :expired }
    end

    trait :expired_by_time do
      expires_at { 1.day.ago }
    end
  end
end
