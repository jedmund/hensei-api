FactoryBot.define do
  factory :phantom_player do
    crew
    sequence(:name) { |n| "Phantom Player #{n}" }
    granblue_id { nil }
    notes { nil }

    trait :with_granblue_id do
      sequence(:granblue_id) { |n| "#{10000000 + n}" }
    end

    trait :claimed do
      transient do
        claimer { nil }
      end

      after(:build) do |phantom, evaluator|
        if evaluator.claimer
          phantom.claimed_by = evaluator.claimer
        else
          # Create a member of the crew
          user = create(:user)
          create(:crew_membership, crew: phantom.crew, user: user, role: :member)
          phantom.claimed_by = user
        end
      end
    end

    trait :confirmed do
      claimed
      claim_confirmed { true }
    end
  end
end
