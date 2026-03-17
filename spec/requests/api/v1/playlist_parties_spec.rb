# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PlaylistParties', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let!(:playlist) { create(:playlist, user: user) }
  let(:party) { create(:party, user: user) }

  describe 'POST /api/v1/playlists/:playlist_id/parties' do
    it 'adds a party to the playlist' do
      expect {
        post "/api/v1/playlists/#{playlist.id}/parties",
             params: { party_id: party.id }.to_json,
             headers: auth_headers
      }.to change(PlaylistParty, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('playlist', 'id')).to eq(playlist.id)
    end

    it 'rejects duplicate party in same playlist with 422' do
      create(:playlist_party, playlist: playlist, party: party)

      expect {
        post "/api/v1/playlists/#{playlist.id}/parties",
             params: { party_id: party.id }.to_json,
             headers: auth_headers
      }.not_to change(PlaylistParty, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-owner' do
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      expect {
        post "/api/v1/playlists/#{playlist.id}/parties",
             params: { party_id: party.id }.to_json,
             headers: other_headers
      }.not_to change(PlaylistParty, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 without authentication' do
      post "/api/v1/playlists/#{playlist.id}/parties",
           params: { party_id: party.id }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/playlists/:playlist_id/parties/:id' do
    let!(:playlist_party) { create(:playlist_party, playlist: playlist, party: party) }

    it 'removes a party from the playlist' do
      expect {
        delete "/api/v1/playlists/#{playlist.id}/parties/#{party.id}", headers: auth_headers
      }.to change(PlaylistParty, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 if party is not in the playlist' do
      other_party = create(:party, user: user)

      delete "/api/v1/playlists/#{playlist.id}/parties/#{other_party.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 for non-owner' do
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      expect {
        delete "/api/v1/playlists/#{playlist.id}/parties/#{party.id}", headers: other_headers
      }.not_to change(PlaylistParty, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
