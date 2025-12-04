FactoryBot.define do
  factory :crew_invitation do
    crew
    user
    status { :pending }
    expires_at { 7.days.from_now }

    # invited_by must be an officer of the crew
    after(:build) do |invitation, _evaluator|
      unless invitation.invited_by
        # Create an officer for the crew if one doesn't exist
        officer = invitation.crew.crew_memberships.find_by(role: [:captain, :vice_captain], retired: false)&.user
        unless officer
          officer = create(:user)
          create(:crew_membership, crew: invitation.crew, user: officer, role: :captain)
        end
        invitation.invited_by = officer
      end
    end

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
