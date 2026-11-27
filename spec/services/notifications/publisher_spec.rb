# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::Publisher do
  let(:owner) { create(:user) }
  let(:party) { create(:party, user: owner, visibility: 1) }
  let(:sticker) { create(:sticker) }

  describe 'stickers' do
    it 'notifies the owner without storing the giver' do
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)

      notification = owner.notifications.sole
      expect(notification).to have_attributes(kind: 'sticker_received', subject: party, actor_id: nil, count: 1)
      expect(notification.payload['sticker_id']).to eq(sticker.id)
    end

    it 'groups stickers into the unread row' do
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)

      expect(owner.notifications.sole.count).to eq(2)
    end

    it "doesn't count a removed and re-added sticker twice" do
      giver = create(:user)
      create(:party_sticker, party: party, user: giver, sticker: sticker)
      PartySticker.find_by(user: giver).destroy!
      create(:party_sticker, party: party, user: giver, sticker: sticker)

      expect(owner.notifications.sole.count).to eq(1)
    end

    it 'counts a new giver after another removed theirs' do
      first = create(:user)
      create(:party_sticker, party: party, user: first, sticker: sticker)
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)
      PartySticker.find_by(user: first).destroy!
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)

      expect(owner.notifications.sole.count).to eq(3)
    end

    it 'starts a new row once the old one is read' do
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)
      owner.notifications.update_all(read_at: Time.current)
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)

      expect(owner.notifications.count).to eq(2)
      expect(owner.notifications.unread.sole.count).to eq(1)
    end

    it "doesn't notify on a team with no owner" do
      ownerless = create(:party, user: nil, visibility: 1)
      expect { create(:party_sticker, party: ownerless, user: create(:user), sticker: sticker) }
        .not_to change(Notification, :count)
    end

    it "doesn't notify when the sticker is changed" do
      other = create(:sticker)
      party_sticker = create(:party_sticker, party: party, user: create(:user), sticker: sticker)
      party_sticker.update!(sticker: other)

      expect(owner.notifications.sole.payload['sticker_id']).to eq(sticker.id)
    end
  end

  describe 'remixes' do
    let(:remixer) { create(:user) }

    def remix_of(source, user)
      create(:party, user: user, source_party: source, remix: true)
    end

    it 'notifies the source owner, naming the remixer' do
      remix = remix_of(party, remixer)

      expect(owner.notifications.sole).to have_attributes(kind: 'party_remixed', subject: party, actor: remixer,
                                                          payload: { 'remix_id' => remix.id })
    end

    it "doesn't notify for remixing your own team" do
      expect { remix_of(party, owner) }.not_to change(Notification, :count)
    end

    it "doesn't notify twice when the same person remixes again" do
      remix_of(party, remixer)
      owner.notifications.update_all(read_at: Time.current)
      remix_of(party, remixer)

      expect(owner.notifications.count).to eq(1)
    end

    it 'groups remixes by different people' do
      remix_of(party, remixer)
      remix_of(party, create(:user))

      expect(owner.notifications.sole.count).to eq(2)
    end
  end

  it 'notifies when a team is featured' do
    create(:featured_party, party: party)
    expect(owner.notifications.sole).to have_attributes(kind: 'party_featured', subject: party)
  end

  describe 'crews' do
    let(:crew) { create(:crew) }
    let(:captain) { create(:user) }

    before { create(:crew_membership, crew: crew, user: captain, role: :captain) }

    it 'notifies the invitee' do
      invitee = create(:user)
      invitation = create(:crew_invitation, crew: crew, user: invitee, invited_by: captain)

      expect(invitee.notifications.sole).to have_attributes(kind: 'crew_invited', subject: invitation,
                                                            actor: captain)
      expect(invitee.notifications.sole.state).to eq('pending')
    end

    it 'notifies a member assigned to a phantom, and reuses the row when reassigned' do
      member = create(:user)
      create(:crew_membership, crew: crew, user: member, role: :member)
      phantom = create(:phantom_player, crew: crew)

      phantom.assign_to(member, by: captain)
      phantom.unassign!
      expect(member.notifications.sole.state).to eq('unassigned')

      phantom.assign_to(member, by: captain)
      expect(member.notifications.sole).to have_attributes(kind: 'phantom_assigned', actor: captain, read_at: nil)
      expect(member.notifications.sole.state).to eq('pending')
    end

    it "doesn't notify an officer who assigns a phantom to themselves" do
      phantom = create(:phantom_player, crew: crew)
      expect { phantom.assign_to(captain, by: captain) }.not_to change(Notification, :count)
    end
  end

  it "keeps the caller's transaction usable when writing fails" do
    allow(Notification).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    ActiveRecord::Base.transaction do
      create(:party_sticker, party: party, user: create(:user), sticker: sticker)
      expect(User.count).to be_positive
    end
  end

  it "doesn't break the action when writing fails" do
    allow(Notification).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { create(:party_sticker, party: party, user: create(:user), sticker: sticker) }
      .to change(PartySticker, :count).by(1)
  end
end
