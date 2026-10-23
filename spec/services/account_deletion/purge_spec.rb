# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountDeletion::Purge do
  let(:user) { create(:user, deletion_scheduled_at: 1.minute.ago) }
  let(:other) { create(:user) }

  describe '.call' do
    it 'deletes the user and their own data' do
      party = create(:party, user: user)
      create(:favorite, user: user, party: create(:party, user: other))
      create(:favorite, user: other, party: party)
      create(:playlist, user: user)
      create(:collection_character, user: user)
      create(:support_summon, user: user)
      user.user_identities.create!(provider: 'google', provider_uid: 'g-1')
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '')

      expect(described_class.call(user)).to be(true)

      expect(User.exists?(user.id)).to be(false)
      expect(Party.exists?(party.id)).to be(false)
      expect(Favorite.where(user_id: [user.id]).or(Favorite.where(party_id: party.id))).to be_empty
      expect(Playlist.where(user_id: user.id)).to be_empty
      expect(CollectionCharacter.where(user_id: user.id)).to be_empty
      expect(SupportSummon.where(user_id: user.id)).to be_empty
      expect(UserIdentity.where(user_id: user.id)).to be_empty
      expect(Doorkeeper::AccessToken.exists?(token.id)).to be(false)
    end

    it "keeps other people's records, without the attribution" do
      party = create(:party, user: user)
      remix = create(:party, user: other, source_party: party)
      imported = create(:party, user: other, collection_source_user: user)
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: other, role: :captain)
      membership = create(:crew_membership, crew: crew, user: user)
      roster = create(:crew_roster, crew: crew, created_by: user)
      score = create(:gw_individual_score, crew_membership: create(:crew_membership, crew: crew), recorded_by: user,
                                           crew_gw_participation: create(:crew_gw_participation, crew: crew))
      own_score = create(:gw_individual_score, crew_membership: membership, recorded_by: other,
                                               crew_gw_participation: score.crew_gw_participation, round: :interlude)
      phantom = create(:phantom_player, crew: crew, claimed_by: user, claim_confirmed: true,
                                        claimed_from_membership: membership)

      described_class.call(user)

      expect(remix.reload.source_party_id).to be_nil
      expect(imported.reload.collection_source_user_id).to be_nil
      expect(roster.reload.created_by_id).to be_nil
      expect(score.reload.recorded_by_id).to be_nil
      expect(own_score.reload.crew_membership_id).to be_nil
      expect(phantom.reload).to have_attributes(claimed_by_id: nil, claim_confirmed: false,
                                                claimed_from_membership_id: nil)
      expect(CrewMembership.exists?(membership.id)).to be(false)
    end

    it 'unlinks the difficulty audit log' do
      log = DifficultyChangeLog.create!(user: user, committed_at: Time.current)

      described_class.call(user)

      expect(log.reload.user_id).to be_nil
    end

    context 'when the user is a crew captain' do
      let(:crew) { create(:crew) }

      before { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'hands captaincy to the longest-serving vice captain' do
        create(:crew_membership, crew: crew, role: :member, joined_at: 3.years.ago)
        newer_vc = create(:crew_membership, crew: crew, role: :vice_captain, joined_at: 1.year.ago)
        older_vc = create(:crew_membership, crew: crew, role: :vice_captain, joined_at: 2.years.ago)

        described_class.call(user)

        expect(older_vc.reload).to be_captain
        expect(newer_vc.reload).to be_vice_captain
      end

      it 'falls back to the longest-serving member' do
        newer = create(:crew_membership, crew: crew, role: :member, joined_at: 1.year.ago)
        older = create(:crew_membership, crew: crew, role: :member, joined_at: 2.years.ago)
        create(:crew_membership, crew: crew, role: :member, retired: true, retired_at: 1.day.ago,
                                 joined_at: 5.years.ago)

        described_class.call(user)

        expect(older.reload).to be_captain
        expect(newer.reload).to be_member
      end

      it 'deletes a crew with nobody left' do
        described_class.call(user)

        expect(Crew.exists?(crew.id)).to be(false)
      end
    end

    it 'does nothing when the deletion was cancelled' do
      user.update_columns(deletion_scheduled_at: nil)

      expect(described_class.call(user)).to be(false)
      expect(User.exists?(user.id)).to be(true)
    end

    it 'does nothing before the deletion date' do
      user.update_columns(deletion_scheduled_at: 1.day.from_now)

      expect(described_class.call(user)).to be(false)
      expect(User.exists?(user.id)).to be(true)
    end
  end
end
