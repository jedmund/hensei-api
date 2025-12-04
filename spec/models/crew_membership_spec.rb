require 'rails_helper'

RSpec.describe CrewMembership, type: :model do
  describe 'associations' do
    it { should belong_to(:crew) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it 'validates uniqueness of user_id scoped to crew_id' do
      crew = create(:crew)
      user = create(:user)
      create(:crew_membership, crew: crew, user: user)

      duplicate = build(:crew_membership, crew: crew, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('has already been taken')
    end
  end

  describe 'role enum' do
    it { should define_enum_for(:role).with_values(member: 0, vice_captain: 1, captain: 2) }
  end

  describe 'scopes' do
    let(:crew) { create(:crew) }

    describe '.active' do
      it 'returns only non-retired memberships' do
        active = create(:crew_membership, crew: crew)
        retired = create(:crew_membership, :retired, crew: crew)

        expect(CrewMembership.active).to include(active)
        expect(CrewMembership.active).not_to include(retired)
      end
    end

    describe '.retired' do
      it 'returns only retired memberships' do
        active = create(:crew_membership, crew: crew)
        retired = create(:crew_membership, :retired, crew: crew)

        expect(CrewMembership.retired).to include(retired)
        expect(CrewMembership.retired).not_to include(active)
      end
    end
  end

  describe 'one active crew per user validation' do
    let(:crew1) { create(:crew) }
    let(:crew2) { create(:crew) }
    let(:user) { create(:user) }

    it 'prevents user from joining multiple active crews' do
      create(:crew_membership, crew: crew1, user: user)
      membership2 = build(:crew_membership, crew: crew2, user: user)

      expect(membership2).not_to be_valid
      expect(membership2.errors[:user]).to include('can only be in one active crew')
    end

    it 'allows user to join new crew after retiring from old one' do
      membership1 = create(:crew_membership, crew: crew1, user: user)
      membership1.retire!

      membership2 = build(:crew_membership, crew: crew2, user: user)
      expect(membership2).to be_valid
    end
  end

  describe 'captain limit validation' do
    let(:crew) { create(:crew) }
    let(:captain_user) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: captain_user)
    end

    it 'prevents multiple captains' do
      new_captain = build(:crew_membership, :captain, crew: crew)

      expect(new_captain).not_to be_valid
      expect(new_captain.errors[:role]).to include('crew can only have one captain')
    end

    it 'allows captain after previous captain retires' do
      crew.crew_memberships.find_by(role: :captain).retire!
      new_captain = build(:crew_membership, :captain, crew: crew)

      expect(new_captain).to be_valid
    end
  end

  describe 'vice captain limit validation' do
    let(:crew) { create(:crew) }

    before do
      create(:crew_membership, :captain, crew: crew)
      3.times { create(:crew_membership, :vice_captain, crew: crew) }
    end

    it 'prevents more than 3 vice captains' do
      fourth_vc = build(:crew_membership, :vice_captain, crew: crew)

      expect(fourth_vc).not_to be_valid
      expect(fourth_vc.errors[:role]).to include('crew can only have up to 3 vice captains')
    end

    it 'allows new vice captain after one retires' do
      crew.crew_memberships.where(role: :vice_captain).first.retire!
      new_vc = build(:crew_membership, :vice_captain, crew: crew)

      expect(new_vc).to be_valid
    end
  end

  describe '#retire!' do
    let(:crew) { create(:crew) }
    let(:user) { create(:user) }
    let(:membership) { create(:crew_membership, :vice_captain, crew: crew, user: user) }

    it 'sets retired to true' do
      membership.retire!
      expect(membership.retired).to be true
    end

    it 'sets retired_at timestamp' do
      membership.retire!
      expect(membership.retired_at).to be_within(1.second).of(Time.current)
    end

    it 'demotes to member role' do
      membership.retire!
      expect(membership.role).to eq('member')
    end
  end
end
