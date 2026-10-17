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

    it 'allows picks without an event' do
      post '/api/v1/featured_parties', params: { featured_party: { party_id: party.id } }, headers: editor_headers
      expect(response).to have_http_status(:created)
      expect(json_response['event_id']).to be_nil
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
end
