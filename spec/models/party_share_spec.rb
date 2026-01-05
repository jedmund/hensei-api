# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyShare, type: :model do
  describe 'associations' do
    it { should belong_to(:party) }
    it { should belong_to(:shareable) }
    it { should belong_to(:shared_by).class_name('User') }
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
      crew2 = create(:crew)
      create(:crew_membership, crew: crew2, user: user)

      share1 = create(:party_share, party: party, shareable: crew, shared_by: user)
      share2 = build(:party_share, party: party, shareable: crew2, shared_by: user)

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
      share = build(:party_share, party: party, shareable: crew, shared_by: other_user)
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
      share = build(:party_share, party: party, shareable: crew, shared_by: user)
      expect(share).not_to be_valid
      expect(share.errors[:shareable]).to include('you must be a member of this crew')
    end

    it 'prevents sharing if user has retired from crew' do
      membership = create(:crew_membership, crew: crew, user: user)
      membership.retire!

      share = build(:party_share, party: party, shareable: crew, shared_by: user)
      expect(share).not_to be_valid
    end
  end

  describe 'scopes' do
    let(:crew1) { create(:crew) }
    let(:crew2) { create(:crew) }
    let(:user) { create(:user) }
    let(:party1) { create(:party, user: user) }
    let(:party2) { create(:party, user: user) }

    before do
      create(:crew_membership, crew: crew1, user: user)
      create(:crew_membership, crew: crew2, user: user)
    end

    describe '.for_crew' do
      it 'returns shares for a specific crew' do
        share1 = create(:party_share, party: party1, shareable: crew1, shared_by: user)
        share2 = create(:party_share, party: party2, shareable: crew2, shared_by: user)

        expect(PartyShare.for_crew(crew1)).to include(share1)
        expect(PartyShare.for_crew(crew1)).not_to include(share2)
      end
    end

    describe '.for_party' do
      it 'returns shares for a specific party' do
        share1 = create(:party_share, party: party1, shareable: crew1, shared_by: user)
        share2 = create(:party_share, party: party2, shareable: crew1, shared_by: user)

        expect(PartyShare.for_party(party1)).to include(share1)
        expect(PartyShare.for_party(party1)).not_to include(share2)
      end
    end
  end
end
