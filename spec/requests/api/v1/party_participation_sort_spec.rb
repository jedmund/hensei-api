# frozen_string_literal: true

require 'rails_helper'

# `sort=rising` (and its old name `sort=participation`) on party lists, and
# when a party's score is recomputed.
RSpec.describe 'Party participation', type: :request do
  def json_response
    JSON.parse(response.body)
  end

  # The explore list hides parties below the default grid counts.
  def listable(party)
    party.update_columns(weapons_count: 5, summons_count: 2, characters_count: 0)
    party
  end

  def result_ids
    json_response['results'].map { |p| p['id'] }
  end

  describe 'sort=rising' do
    let!(:unscored) { listable(create(:party, visibility: 1)) }
    let!(:low) { listable(create(:party, visibility: 1)) }
    let!(:high) { listable(create(:party, visibility: 1)) }
    let!(:unlisted) { listable(create(:party, visibility: 2)) }

    before do
      low.update_columns(participation_score: 1.5)
      high.update_columns(participation_score: 4.0)
      unlisted.update_columns(participation_score: 9.0)
    end

    it 'lists only public parties with a score, highest first' do
      get '/api/v1/parties', params: { sort: 'rising' }
      expect(result_ids).to eq([high.id, low.id])
    end

    it 'ranks a new party above an older one with double its score' do
      old = listable(create(:party, visibility: 1, created_at: 30.days.ago))
      newer = listable(create(:party, visibility: 1, created_at: 1.hour.ago))
      old.update_columns(participation_score: 10.0)
      newer.update_columns(participation_score: 5.0)

      get '/api/v1/parties', params: { sort: 'rising' }
      ids = result_ids
      expect(ids.index(newer.id)).to be < ids.index(old.id)
    end

    it 'breaks ties by id' do
      low.update_columns(participation_score: 4.0, created_at: high.created_at)
      get '/api/v1/parties', params: { sort: 'rising' }
      expect(result_ids).to eq([high.id, low.id].sort)
    end

    it 'keeps other filters and pagination' do
      high.update_columns(element: 2)
      low.update_columns(element: 3)
      get '/api/v1/parties', params: { sort: 'rising', element: 3 }
      expect(result_ids).to eq([low.id])
      expect(json_response['meta']['count']).to eq(1)
    end

    it 'accepts sort=participation as an alias' do
      get '/api/v1/parties', params: { sort: 'participation' }
      expect(result_ids).to eq([high.id, low.id])
    end

    it 'keeps newest first by default' do
      get '/api/v1/parties'
      expect(result_ids.first(3)).to eq([high.id, low.id, unscored.id])
    end

    it 'works on favorites too' do
      user = create(:user)
      create(:favorite, user: user, party: low)
      create(:favorite, user: user, party: high)
      create(:favorite, user: user, party: unscored)
      get '/api/v1/parties/favorites', params: { sort: 'rising' }, headers: bearer_headers(user)
      expect(response).to have_http_status(:ok)
      expect(result_ids).to eq([high.id, low.id])
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
