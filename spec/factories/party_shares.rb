# frozen_string_literal: true

FactoryBot.define do
  factory :party_share do
    party
    association :shareable, factory: :crew
    association :shared_by, factory: :user

    # Ensure the shared_by user owns the party and is in the crew
    after(:build) do |party_share|
      party_share.party.user = party_share.shared_by
      unless party_share.shareable.crew_memberships.exists?(user: party_share.shared_by, retired: false)
        create(:crew_membership, crew: party_share.shareable, user: party_share.shared_by)
      end
    end
  end
end
