require 'rails_helper'

RSpec.describe CrewInvitation, type: :model do
  let(:crew) { create(:crew) }
  let(:captain) { create(:user) }
  let(:invitee) { create(:user) }

  before do
    create(:crew_membership, :captain, crew: crew, user: captain)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:crew) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:invited_by).class_name('User') }
  end

  describe 'validations' do
    context 'when user is already in a crew' do
      let(:other_crew) { create(:crew) }

      before do
        create(:crew_membership, crew: other_crew, user: invitee)
      end

      it 'is invalid' do
        invitation = build(:crew_invitation, crew: crew, user: invitee, invited_by: captain)
        expect(invitation).not_to be_valid
        expect(invitation.errors[:user]).to include('is already in a crew')
      end
    end

    context 'when inviter is not an officer' do
      let(:regular_member) { create(:user) }

      before do
        create(:crew_membership, crew: crew, user: regular_member)
      end

      it 'is invalid' do
        invitation = build(:crew_invitation, crew: crew, user: invitee, invited_by: regular_member)
        expect(invitation).not_to be_valid
        expect(invitation.errors[:invited_by]).to include('must be an officer of the crew')
      end
    end

    context 'when inviter is captain' do
      it 'is valid' do
        invitation = build(:crew_invitation, crew: crew, user: invitee, invited_by: captain)
        expect(invitation).to be_valid
      end
    end

    context 'when inviter is vice captain' do
      let(:vice_captain) { create(:user) }

      before do
        create(:crew_membership, :vice_captain, crew: crew, user: vice_captain)
      end

      it 'is valid' do
        invitation = build(:crew_invitation, crew: crew, user: invitee, invited_by: vice_captain)
        expect(invitation).to be_valid
      end
    end
  end

  describe '#accept!' do
    let(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'creates a crew membership' do
      expect { invitation.accept! }.to change(CrewMembership, :count).by(1)
    end

    it 'sets the invitation status to accepted' do
      invitation.accept!
      expect(invitation.reload.status).to eq('accepted')
    end

    it 'makes the user a member of the crew' do
      invitation.accept!
      expect(invitee.reload.crew).to eq(crew)
      expect(invitee.crew_role).to eq('member')
    end

    context 'when invitation is expired by time' do
      let(:invitation) { create(:crew_invitation, :expired_by_time, crew: crew, user: invitee, invited_by: captain) }

      it 'raises InvitationExpiredError' do
        expect { invitation.accept! }.to raise_error(CrewErrors::InvitationExpiredError)
      end
    end

    context 'when invitation status is expired' do
      let(:invitation) { create(:crew_invitation, :expired, crew: crew, user: invitee, invited_by: captain) }

      it 'raises InvitationExpiredError' do
        expect { invitation.accept! }.to raise_error(CrewErrors::InvitationExpiredError)
      end
    end

    context 'when user joins another crew after invitation was created' do
      let(:other_crew) { create(:crew) }

      it 'raises AlreadyInCrewError' do
        # Create invitation first while user is not in any crew
        inv = invitation

        # Then user joins another crew
        create(:crew_membership, :captain, crew: other_crew)
        create(:crew_membership, crew: other_crew, user: invitee)

        # Now accepting should fail
        expect { inv.accept! }.to raise_error(CrewErrors::AlreadyInCrewError)
      end
    end
  end

  describe '#reject!' do
    let(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'sets the invitation status to rejected' do
      invitation.reject!
      expect(invitation.reload.status).to eq('rejected')
    end

    context 'when invitation is already expired' do
      let(:invitation) { create(:crew_invitation, :expired, crew: crew, user: invitee, invited_by: captain) }

      it 'raises InvitationExpiredError' do
        expect { invitation.reject! }.to raise_error(CrewErrors::InvitationExpiredError)
      end
    end
  end

  describe '#active?' do
    context 'when pending and not expired' do
      let(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

      it 'returns true' do
        expect(invitation.active?).to be true
      end
    end

    context 'when pending but expired by time' do
      let(:invitation) { create(:crew_invitation, :expired_by_time, crew: crew, user: invitee, invited_by: captain) }

      it 'returns false' do
        expect(invitation.active?).to be false
      end
    end

    context 'when already accepted' do
      let(:invitation) { create(:crew_invitation, :accepted, crew: crew, user: invitee, invited_by: captain) }

      it 'returns false' do
        expect(invitation.active?).to be false
      end
    end
  end

  describe 'expiration' do
    it 'sets default expiration to 7 days' do
      invitation = create(:crew_invitation, crew: crew, user: invitee, invited_by: captain, expires_at: nil)
      expect(invitation.expires_at).to be_within(1.minute).of(7.days.from_now)
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }
      let(:other_user) { create(:user) }
      let!(:expired_invitation) { create(:crew_invitation, :expired_by_time, crew: crew, user: other_user, invited_by: captain) }

      it 'returns only active invitations' do
        expect(CrewInvitation.active).to include(active_invitation)
        expect(CrewInvitation.active).not_to include(expired_invitation)
      end
    end
  end
end
