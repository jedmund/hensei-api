require 'rails_helper'

RSpec.describe Crew, type: :model do
  describe 'associations' do
    it { should have_many(:crew_memberships).dependent(:destroy) }
    it { should have_many(:users).through(:crew_memberships) }
    it { should have_many(:active_memberships) }
    it { should have_many(:active_members).through(:active_memberships) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:gamertag).is_at_most(50) }

    context 'granblue_crew_id uniqueness' do
      it 'validates uniqueness' do
        crew1 = create(:crew, granblue_crew_id: 'ABC123')
        crew2 = build(:crew, granblue_crew_id: 'ABC123')
        expect(crew2).not_to be_valid
        expect(crew2.errors[:granblue_crew_id]).to include('has already been taken')
      end

      it 'allows nil values' do
        create(:crew, granblue_crew_id: nil)
        crew2 = build(:crew, granblue_crew_id: nil)
        expect(crew2).to be_valid
      end
    end
  end

  describe '#captain' do
    let(:crew) { create(:crew) }
    let(:captain_user) { create(:user) }
    let(:member_user) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: captain_user)
      create(:crew_membership, crew: crew, user: member_user)
    end

    it 'returns the captain user' do
      expect(crew.captain).to eq(captain_user)
    end

    it 'returns nil if no captain' do
      crew.crew_memberships.find_by(role: :captain).update!(role: :member)
      expect(crew.captain).to be_nil
    end

    it 'does not return retired captains' do
      crew.crew_memberships.find_by(role: :captain).retire!
      expect(crew.captain).to be_nil
    end
  end

  describe '#vice_captains' do
    let(:crew) { create(:crew) }
    let(:captain_user) { create(:user) }
    let(:vc1) { create(:user) }
    let(:vc2) { create(:user) }
    let(:member_user) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: captain_user)
      create(:crew_membership, :vice_captain, crew: crew, user: vc1)
      create(:crew_membership, :vice_captain, crew: crew, user: vc2)
      create(:crew_membership, crew: crew, user: member_user)
    end

    it 'returns all vice captains' do
      expect(crew.vice_captains).to contain_exactly(vc1, vc2)
    end

    it 'does not include retired vice captains' do
      crew.crew_memberships.find_by(user: vc1).retire!
      expect(crew.vice_captains).to contain_exactly(vc2)
    end
  end

  describe '#officers' do
    let(:crew) { create(:crew) }
    let(:captain_user) { create(:user) }
    let(:vc1) { create(:user) }
    let(:member_user) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: captain_user)
      create(:crew_membership, :vice_captain, crew: crew, user: vc1)
      create(:crew_membership, crew: crew, user: member_user)
    end

    it 'returns captain and vice captains' do
      expect(crew.officers).to contain_exactly(captain_user, vc1)
    end

    it 'does not include regular members' do
      expect(crew.officers).not_to include(member_user)
    end
  end

  describe '#member_count' do
    let(:crew) { create(:crew) }

    before do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, crew: crew)
      create(:crew_membership, :retired, crew: crew)
    end

    it 'returns count of active members only' do
      expect(crew.member_count).to eq(2)
    end
  end

  describe 'active_members scope' do
    let(:crew) { create(:crew) }
    let(:active_user) { create(:user) }
    let(:retired_user) { create(:user) }

    before do
      create(:crew_membership, crew: crew, user: active_user)
      create(:crew_membership, :retired, crew: crew, user: retired_user)
    end

    it 'returns only active members' do
      expect(crew.active_members).to contain_exactly(active_user)
    end

    it 'does not include retired members' do
      expect(crew.active_members).not_to include(retired_user)
    end
  end
end
