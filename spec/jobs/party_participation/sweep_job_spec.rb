# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyParticipation::SweepJob do
  let(:sticker) { create(:sticker) }

  it 'scores parties with recent activity and decays stale scores to 0' do
    active = create(:party, visibility: 1)
    create(:party_sticker, party: active, sticker: sticker, user: trusted_user)
    stale = create(:party, visibility: 1)
    stale.update_columns(participation_score: 2.5)
    untouched = create(:party, visibility: 1)

    described_class.perform_now

    expect(active.reload.participation_score).to be_positive
    expect(stale.reload.participation_score).to eq(0)
    expect(untouched.reload.participation_computed_at).to be_nil
  end
end
