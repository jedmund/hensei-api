# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyParticipation::ScoreJob do
  it 'recomputes one party' do
    party = create(:party, visibility: 1)
    create(:party_sticker, party: party, sticker: create(:sticker), user: trusted_user)
    described_class.perform_now(party.id)
    expect(party.reload.participation_score).to be_positive
  end

  it 'ignores a deleted party' do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
