# frozen_string_literal: true

require 'rails_helper'

# `sort=participation` on party lists, and when a party's score is recomputed.
RSpec.describe 'Party participation', type: :request do
  def json_response
    JSON.parse(response.body)
  end

  # The explore list hides parties below the default grid counts.
  def listable(party)
    party.update_columns(weapons_count: 5, summons_count: 2, characters_count: 0)
    party
  end

  describe 'sort=participation' do
    let!(:unscored) { listable(create(:party, visibility: 1)) }
    let!(:low) { listable(create(:party, visibility: 1)) }
    let!(:high) { listable(create(:party, visibility: 1)) }

    before do
      low.update_columns(participation_score: 1.5)
      high.update_columns(participation_score: 4.0)
    end

    it 'sorts by participation score with unscored parties last' do
      get '/api/v1/parties', params: { sort: 'participation' }
      ids = json_response['results'].map { |p| p['id'] }
      expect(ids.first(2)).to eq([high.id, low.id])
      expect(ids).to include(unscored.id)
    end

    it 'works on favorites too' do
      user = create(:user)
      create(:favorite, user: user, party: low)
      create(:favorite, user: user, party: high)
      get '/api/v1/parties/favorites', params: { sort: 'participation' }, headers: bearer_headers(user)
      expect(response).to have_http_status(:ok)
      expect(json_response['results'].map { |p| p['id'] }).to eq([high.id, low.id])
    end
  end

  describe 'recomputing a score' do
    include ActiveJob::TestHelper

    let(:party) { create(:party, visibility: 1) }

    it 'happens when a sticker is given or taken back' do
      party_sticker = nil
      expect { party_sticker = create(:party_sticker, party: party) }
        .to have_enqueued_job(PartyParticipation::ScoreJob).with(party.id)
      expect { party_sticker.destroy! }.to have_enqueued_job(PartyParticipation::ScoreJob).with(party.id)
    end

    it 'does not happen when a sticker is moved or swapped' do
      party_sticker = create(:party_sticker, party: party)
      expect { party_sticker.update!(x: 0.5, y: 10, sticker: create(:sticker)) }
        .not_to have_enqueued_job(PartyParticipation::ScoreJob)
    end
  end
end
