# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyParticipation::Persister do
  let(:sticker) { create(:sticker) }

  it 'stores the score and computed_at without bumping updated_at' do
    party = create(:party, visibility: 1)
    create(:party_sticker, party: party, sticker: sticker, user: trusted_user)
    updated_at = party.reload.updated_at

    described_class.call([party.id])

    party.reload
    expect(party.participation_score).to be_within(0.01).of(1.0)
    expect(party.participation_computed_at).to be_present
    expect(party.updated_at).to eq(updated_at)
  end

  it 'stores 0 for non-public parties, keeping their stickers' do
    party = create(:party, visibility: 2)
    create(:party_sticker, party: party, sticker: sticker, user: trusted_user)

    described_class.call([party.id])

    expect(party.reload.participation_score).to eq(0)
    expect(party.party_stickers.count).to eq(1)
  end

  it 'floors tiny scores to 0' do
    party = create(:party, visibility: 1)
    create(:party_sticker, party: party, sticker: sticker, user: trusted_user, created_at: 200.days.ago)

    described_class.call([party.id])

    expect(party.reload.participation_score).to eq(0)
  end
end
