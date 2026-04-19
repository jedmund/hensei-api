require 'rails_helper'

RSpec.describe PhantomPlayer, type: :model do
  describe 'associations' do
    it { should belong_to(:crew) }
    it { should belong_to(:claimed_by).class_name('User').optional }
    it { should belong_to(:claimed_from_membership).class_name('CrewMembership').optional }
    it { should have_many(:gw_individual_scores) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:granblue_id).is_at_most(20) }

    describe 'granblue_id uniqueness within crew' do
      let(:crew) { create(:crew) }
      let!(:existing) { create(:phantom_player, crew: crew, granblue_id: '12345678') }

      it 'rejects duplicate granblue_id in same crew' do
        phantom = build(:phantom_player, crew: crew, granblue_id: '12345678')
        expect(phantom).not_to be_valid
        expect(phantom.errors[:granblue_id]).to be_present
      end

      it 'allows same granblue_id in different crew' do
        other_crew = create(:crew)
        phantom = build(:phantom_player, crew: other_crew, granblue_id: '12345678')
        expect(phantom).to be_valid
      end

      it 'allows multiple nil granblue_ids in same crew' do
        phantom = build(:phantom_player, crew: crew, granblue_id: nil)
        expect(phantom).to be_valid
      end
    end

    describe 'claimed_by must be crew member' do
      let(:crew) { create(:crew) }
      let(:phantom) { build(:phantom_player, crew: crew) }

      it 'accepts claimed_by who is a crew member' do
        member = create(:user)
        create(:crew_membership, crew: crew, user: member, role: :member)
        phantom.claimed_by = member
        expect(phantom).to be_valid
      end

      it 'rejects claimed_by who is not a crew member' do
        non_member = create(:user)
        phantom.claimed_by = non_member
        expect(phantom).not_to be_valid
        expect(phantom.errors[:claimed_by]).to include('must be a member of this crew')
      end
    end

    describe 'claim_confirmed requires claimed_by' do
      let(:phantom) { build(:phantom_player, claim_confirmed: true, claimed_by: nil) }

      it 'is invalid' do
        expect(phantom).not_to be_valid
        expect(phantom.errors[:claim_confirmed]).to include('requires a claimed_by user')
      end
    end
  end

  describe 'scopes' do
    let(:crew) { create(:crew) }
    let(:member) { create(:user) }
    let!(:membership) { create(:crew_membership, crew: crew, user: member, role: :member) }
    let!(:unclaimed) { create(:phantom_player, crew: crew) }
    let!(:claimed) { create(:phantom_player, crew: crew, claimed_by: member) }
    let!(:confirmed) { create(:phantom_player, crew: crew, claimed_by: member, claim_confirmed: true) }

    describe '.unclaimed' do
      it 'returns only unclaimed phantoms' do
        expect(PhantomPlayer.unclaimed).to contain_exactly(unclaimed)
      end
    end

    describe '.claimed' do
      it 'returns claimed phantoms (confirmed or not)' do
        expect(PhantomPlayer.claimed).to contain_exactly(claimed, confirmed)
      end
    end

    describe '.pending_confirmation' do
      it 'returns claimed but unconfirmed phantoms' do
        expect(PhantomPlayer.pending_confirmation).to contain_exactly(claimed)
      end
    end
  end

  describe '#assign_to' do
    let(:crew) { create(:crew) }
    let(:phantom) { create(:phantom_player, crew: crew) }
    let(:member) { create(:user) }
    let!(:membership) { create(:crew_membership, crew: crew, user: member, role: :member) }

    it 'assigns the phantom to the user' do
      phantom.assign_to(member)
      expect(phantom.claimed_by).to eq(member)
      expect(phantom.claim_confirmed).to be false
    end

    it 'raises error for non-crew member' do
      non_member = create(:user)
      expect { phantom.assign_to(non_member) }.to raise_error(CrewErrors::MemberNotFoundError)
    end
  end

  describe '#confirm_claim!' do
    let(:crew) { create(:crew) }
    let(:member) { create(:user) }
    let!(:membership) { create(:crew_membership, crew: crew, user: member, role: :member) }
    let(:phantom) { create(:phantom_player, crew: crew, claimed_by: member) }

    it 'confirms the claim' do
      phantom.confirm_claim!(member)
      expect(phantom.claim_confirmed).to be true
    end

    it 'raises error for wrong user' do
      other_user = create(:user)
      create(:crew_membership, crew: crew, user: other_user, role: :member)
      expect { phantom.confirm_claim!(other_user) }.to raise_error(CrewErrors::NotClaimedByUserError)
    end

    context 'with individual scores' do
      let(:gw_event) { create(:gw_event) }
      let(:participation) { create(:crew_gw_participation, crew: crew, gw_event: gw_event) }
      let!(:phantom_score) do
        create(:gw_individual_score,
               crew_gw_participation: participation,
               phantom_player: phantom,
               crew_membership: nil,
               score: 1_000_000)
      end

      it 'transfers scores to the membership' do
        phantom.confirm_claim!(member)
        phantom_score.reload

        expect(phantom_score.crew_membership).to eq(membership)
        expect(phantom_score.phantom_player).to be_nil
      end
    end

    context 'joined_at transfer' do
      it "copies the phantom's joined_at to the membership when earlier" do
        earlier = 1.year.ago
        phantom.update!(joined_at: earlier)
        membership.update!(joined_at: 1.day.ago)

        phantom.confirm_claim!(member)
        expect(membership.reload.joined_at).to be_within(1.second).of(earlier)
      end

      it 'does not overwrite a membership joined_at that is already earlier' do
        phantom.update!(joined_at: 1.day.ago)
        older = 2.years.ago
        membership.update!(joined_at: older)

        phantom.confirm_claim!(member)
        expect(membership.reload.joined_at).to be_within(1.second).of(older)
      end
    end
  end

  describe '#unassign!' do
    let(:crew) { create(:crew) }
    let(:member) { create(:user) }
    let!(:membership) { create(:crew_membership, crew: crew, user: member, role: :member) }
    let(:phantom) { create(:phantom_player, crew: crew, claimed_by: member) }

    it 'removes the assignment' do
      phantom.unassign!
      expect(phantom.claimed_by).to be_nil
      expect(phantom.claim_confirmed).to be false
    end
  end
end
