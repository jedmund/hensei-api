# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyShare, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:party) }
    it { is_expected.to belong_to(:shareable) }
    it { is_expected.to belong_to(:shared_by).class_name('User') }
  end

  describe 'validations' do
    let(:crew) { create(:crew) }
    let(:user) { create(:user) }
    let(:party) { create(:party, user: user) }

    before do
      create(:crew_membership, crew: crew, user: user)
    end

    it 'validates uniqueness of party scoped to shareable' do
      create(:party_share, party: party, shareable: crew, shared_by: user)

      duplicate = build(:party_share, party: party, shareable: crew, shared_by: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:party_id]).to include('has already been shared with this group')
    end

    it 'allows same party to be shared with different crews' do
      second_crew = create(:crew)
      # Retire from first crew to respect one-active-crew-per-user
      CrewMembership.find_by(crew: crew, user: user).retire!
      create(:crew_membership, crew: second_crew, user: user)

      share2 = build(:party_share, party: party, shareable: second_crew, shared_by: user)

      expect(share2).to be_valid
    end
  end

  describe 'owner validation' do
    let(:crew) { create(:crew) }
    let(:owner) { create(:user) }
    let(:other_user) { create(:user) }
    let(:party) { create(:party, user: owner) }

    before do
      create(:crew_membership, crew: crew, user: owner)
      create(:crew_membership, crew: crew, user: other_user)
    end

    it 'allows owner to share their party' do
      share = build(:party_share, party: party, shareable: crew, shared_by: owner)
      expect(share).to be_valid
    end

    it 'prevents non-owner from sharing the party' do
      share = described_class.new(party: party, shareable: crew, shared_by: other_user)
      expect(share).not_to be_valid
      expect(share.errors[:shared_by]).to include('must be the party owner')
    end
  end

  describe 'crew membership validation' do
    let(:crew) { create(:crew) }
    let(:user) { create(:user) }
    let(:party) { create(:party, user: user) }

    it 'allows sharing to a crew the user belongs to' do
      create(:crew_membership, crew: crew, user: user)
      share = build(:party_share, party: party, shareable: crew, shared_by: user)
      expect(share).to be_valid
    end

    it 'prevents sharing to a crew the user does not belong to' do
      share = described_class.new(party: party, shareable: crew, shared_by: user)
      expect(share).not_to be_valid
      expect(share.errors[:shareable]).to include('you must be a member of this crew')
    end

    it 'prevents sharing if user has retired from crew' do
      membership = create(:crew_membership, crew: crew, user: user)
      membership.retire!

      share = described_class.new(party: party, shareable: crew, shared_by: user)
      expect(share).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:first_crew) { create(:crew) }
    let(:second_crew) { create(:crew) }
    let(:first_user) { create(:user) }
    let(:second_user) { create(:user) }
    let(:first_party) { create(:party, user: first_user) }
    let(:second_party) { create(:party, user: second_user) }

    before do
      create(:crew_membership, crew: first_crew, user: first_user)
      create(:crew_membership, crew: second_crew, user: second_user)
    end

    describe '.for_crew' do
      it 'returns shares for a specific crew' do
        share1 = create(:party_share, party: first_party, shareable: first_crew, shared_by: first_user)
        share2 = create(:party_share, party: second_party, shareable: second_crew, shared_by: second_user)

        expect(described_class.for_crew(first_crew)).to include(share1)
        expect(described_class.for_crew(first_crew)).not_to include(share2)
      end
    end

    describe '.for_party' do
      it 'returns shares for a specific party' do
        party3 = create(:party, user: first_user)
        share1 = create(:party_share, party: first_party, shareable: first_crew, shared_by: first_user)
        share2 = create(:party_share, party: party3, shareable: first_crew, shared_by: first_user)

        expect(described_class.for_party(first_party)).to include(share1)
        expect(described_class.for_party(first_party)).not_to include(share2)
      end
    end
  end
end
