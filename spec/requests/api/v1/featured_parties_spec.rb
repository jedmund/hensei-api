# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::FeaturedParties', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:member) { create(:user, role: 1) }
  let(:editor_headers) { bearer_headers(editor) }
  let(:member_headers) { bearer_headers(member) }
  let(:party) { create(:party, visibility: 1) }
  let(:event) { create(:event) }

  def json_response
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/featured_parties' do
    let!(:second) { create(:featured_party, event: event, position: 2) }
    let!(:first) { create(:featured_party, event: event, position: 1) }
    let!(:eventless) { create(:featured_party, position: 0) }

    it "lists an event's picks by position" do
      get '/api/v1/featured_parties', params: { event_id: event.id }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(json_response['featured_parties'].map { |p| p['id'] }).to eq([first.id, second.id])
      expect(json_response['featured_parties'].first['party']['id']).to eq(first.party_id)
    end

    it 'lists all picks without event_id' do
      get '/api/v1/featured_parties', headers: editor_headers
      expect(json_response['featured_parties'].map { |p| p['id'] }).to eq([eventless.id, first.id, second.id])
    end

    it "filters by party_id to show where a team is featured" do
      get '/api/v1/featured_parties', params: { party_id: first.party_id }, headers: editor_headers
      expect(json_response['featured_parties'].map { |p| p['id'] }).to eq([first.id])
    end

    it 'returns 401 for non-editors' do
      get '/api/v1/featured_parties', headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/featured_parties' do
    let(:params) { { featured_party: { event_id: event.id, party_id: party.id, position: 1, note_en: 'Great', note_jp: '良い' } } }

    it 'creates a staff pick with the party list view' do
      post '/api/v1/featured_parties', params: params, headers: editor_headers

      expect(response).to have_http_status(:created)
      expect(json_response).to include('event_id' => event.id, 'position' => 1, 'note' => { 'en' => 'Great', 'ja' => '良い' })
      expect(json_response['party']).to include('id' => party.id, 'shortcode' => party.shortcode, 'labels' => [])
    end

    it 'allows picks without an event, which expire after 30 days' do
      freeze_time do
        post '/api/v1/featured_parties', params: { featured_party: { party_id: party.id } }, headers: editor_headers
        expect(response).to have_http_status(:created)
        expect(json_response['event_id']).to be_nil
        expect(json_response['expires_at']).to eq(30.days.from_now.iso8601)
      end
    end

    it 'gives event picks no expiry of their own' do
      post '/api/v1/featured_parties', params: params, headers: editor_headers
      expect(json_response['expires_at']).to be_nil
    end

    it 'replaces an expired general pick when the team is featured again' do
      old = create(:featured_party, party: party, created_at: 31.days.ago)

      post '/api/v1/featured_parties', params: { featured_party: { party_id: party.id } }, headers: editor_headers

      expect(response).to have_http_status(:created)
      expect(FeaturedParty.exists?(old.id)).to be(false)
      expect(FeaturedParty.where(party: party).count).to eq(1)
    end

    it 'rejects a non-public party' do
      party.update!(visibility: 3)
      post '/api/v1/featured_parties', params: params, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an unknown event' do
      post '/api/v1/featured_parties',
           params: { featured_party: { party_id: party.id, event_id: '00000000-0000-0000-0000-000000000000' } },
           headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-editors' do
      post '/api/v1/featured_parties', params: params, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(FeaturedParty.count).to eq(0)
    end
  end

  describe 'PUT and DELETE /api/v1/featured_parties/:id' do
    let!(:featured) { create(:featured_party, party: party) }

    it 'updates as an editor' do
      put "/api/v1/featured_parties/#{featured.id}", params: { featured_party: { note_en: 'Updated' } }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(json_response['note']['en']).to eq('Updated')
    end

    it 'deletes as an editor' do
      delete "/api/v1/featured_parties/#{featured.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
      expect(FeaturedParty.exists?(featured.id)).to be(false)
    end

    it 'returns 401 for non-editors' do
      put "/api/v1/featured_parties/#{featured.id}", params: { featured_party: { note_en: 'x' } }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      delete "/api/v1/featured_parties/#{featured.id}", headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(FeaturedParty.exists?(featured.id)).to be(true)
    end
  end

  describe 'as a curator' do
    let(:curator_headers) { bearer_headers(create(:user, role: 6)) }
    let(:upcoming) { create(:event, :upcoming) }
    let(:ended) { create(:event, :past) }

    it 'lists picks' do
      pick = create(:featured_party, event: event)
      get '/api/v1/featured_parties', params: { party_id: pick.party_id }, headers: curator_headers
      expect(response).to have_http_status(:ok)
      expect(json_response['featured_parties'].map { |p| p['id'] }).to eq([pick.id])
    end

    it 'creates picks for running and upcoming events and general picks' do
      [event.id, upcoming.id, nil].each do |event_id|
        post '/api/v1/featured_parties', params: { featured_party: { event_id: event_id, party_id: party.id } },
                                         headers: curator_headers
        expect(response).to have_http_status(:created)
      end
      expect(FeaturedParty.count).to eq(3)
    end

    it 'updates and deletes a pick for a running event' do
      pick = create(:featured_party, event: event, party: party)
      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { note_en: 'Updated', event_id: upcoming.id } },
                                                 headers: curator_headers
      expect(response).to have_http_status(:ok)
      expect(json_response).to include('event_id' => upcoming.id)

      delete "/api/v1/featured_parties/#{pick.id}", headers: curator_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'updates and deletes a general pick' do
      pick = create(:featured_party, party: party)
      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { position: 4 } }, headers: curator_headers
      expect(response).to have_http_status(:ok)

      delete "/api/v1/featured_parties/#{pick.id}", headers: curator_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'cannot create a pick for an ended event' do
      post '/api/v1/featured_parties', params: { featured_party: { event_id: ended.id, party_id: party.id } },
                                       headers: curator_headers
      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']).to be_present
      expect(FeaturedParty.count).to eq(0)
    end

    it "cannot update or delete an ended event's pick" do
      pick = create(:featured_party, event: ended, party: party)
      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { note_en: 'x' } }, headers: curator_headers
      expect(response).to have_http_status(:forbidden)

      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { event_id: event.id } },
                                                 headers: curator_headers
      expect(response).to have_http_status(:forbidden)

      delete "/api/v1/featured_parties/#{pick.id}", headers: curator_headers
      expect(response).to have_http_status(:forbidden)
      expect(pick.reload.note_en).to eq('A great team')
    end

    it 'cannot move a pick into an ended event' do
      pick = create(:featured_party, event: event, party: party)
      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { event_id: ended.id } },
                                                 headers: curator_headers
      expect(response).to have_http_status(:forbidden)
      expect(pick.reload.event_id).to eq(event.id)
    end

    it 'rejects a non-public party' do
      party.update!(visibility: 2)
      post '/api/v1/featured_parties', params: { featured_party: { party_id: party.id } }, headers: curator_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "leaves editors free to change an ended event's picks" do
      pick = create(:featured_party, event: ended, party: party)
      put "/api/v1/featured_parties/#{pick.id}", params: { featured_party: { note_en: 'Edited' } }, headers: editor_headers
      expect(response).to have_http_status(:ok)

      delete "/api/v1/featured_parties/#{pick.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'without the curator role' do
    let!(:pick) { create(:featured_party, event: event, party: party) }

    it 'rejects role 5' do
      headers = bearer_headers(create(:user, role: 5))
      get '/api/v1/featured_parties', headers: headers
      expect(response).to have_http_status(:unauthorized)
      post '/api/v1/featured_parties', params: { featured_party: { party_id: party.id } }, headers: headers
      expect(response).to have_http_status(:unauthorized)
      delete "/api/v1/featured_parties/#{pick.id}", headers: headers
      expect(response).to have_http_status(:unauthorized)
      expect(FeaturedParty.count).to eq(1)
    end

    it 'rejects signed-out requests' do
      get '/api/v1/featured_parties'
      expect(response).to have_http_status(:unauthorized)
      delete "/api/v1/featured_parties/#{pick.id}"
      expect(response).to have_http_status(:unauthorized)
      expect(FeaturedParty.exists?(pick.id)).to be(true)
    end
  end
end
