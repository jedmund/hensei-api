# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Playlists', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:unauth_headers) { { 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/users/:user_id/playlists' do
    let!(:public_playlist) { create(:playlist, user: user, visibility: 1) }
    let!(:unlisted_playlist) { create(:playlist, user: user, visibility: 2) }
    let!(:private_playlist) { create(:playlist, user: user, visibility: 3) }

    it 'returns only public and unlisted playlists for non-owner' do
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      get "/api/v1/users/#{user.username}/playlists", headers: other_headers
      expect(response).to have_http_status(:ok)

      ids = response.parsed_body['results'].map { |p| p['id'] }
      expect(ids).to include(public_playlist.id, unlisted_playlist.id)
      expect(ids).not_to include(private_playlist.id)
    end

    it 'returns all playlists for the owner' do
      get "/api/v1/users/#{user.username}/playlists", headers: auth_headers
      expect(response).to have_http_status(:ok)

      ids = response.parsed_body['results'].map { |p| p['id'] }
      expect(ids).to include(public_playlist.id, unlisted_playlist.id, private_playlist.id)
    end

    it 'includes party_count in each result' do
      create_list(:playlist_party, 3, playlist: public_playlist)

      get "/api/v1/users/#{user.username}/playlists", headers: auth_headers
      playlist_json = response.parsed_body['results'].find { |p| p['id'] == public_playlist.id }
      expect(playlist_json['party_count']).to eq(3)
    end

    it 'includes pagination meta' do
      get "/api/v1/users/#{user.username}/playlists", headers: auth_headers
      expect(response.parsed_body['meta']).to include('count', 'total_pages', 'per_page')
    end

    it 'finds the user when the username is in a different case' do
      get "/api/v1/users/#{user.username.upcase}/playlists", headers: unauth_headers
      expect(response).to have_http_status(:ok)

      ids = response.parsed_body['results'].map { |p| p['id'] }
      expect(ids).to include(public_playlist.id)
    end
  end

  describe 'GET /api/v1/users/:user_id/playlists/:id' do
    it 'finds the playlist when the username is in a different case' do
      playlist = create(:playlist, user: user, visibility: 1)

      get "/api/v1/users/#{user.username.upcase}/playlists/#{playlist.slug}", headers: unauth_headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns a public playlist with parties ordered by last_updated desc' do
      playlist = create(:playlist, user: user, visibility: 1)
      old_party = create(:party, user: user, last_updated: 2.days.ago)
      new_party = create(:party, user: user, last_updated: 1.hour.ago)
      create(:playlist_party, playlist: playlist, party: old_party)
      create(:playlist_party, playlist: playlist, party: new_party)

      get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}", headers: unauth_headers
      expect(response).to have_http_status(:ok)

      party_ids = response.parsed_body.dig('playlist', 'parties').map { |p| p['id'] }
      expect(party_ids).to eq([new_party.id, old_party.id])
    end

    it 'returns 404 for a private playlist viewed by non-owner' do
      playlist = create(:playlist, user: user, visibility: 3)

      get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}", headers: unauth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'allows the owner to view their private playlist' do
      playlist = create(:playlist, user: user, visibility: 3)

      get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('playlist', 'id')).to eq(playlist.id)
    end

    it 'returns 404 for nonexistent playlist' do
      get "/api/v1/users/#{user.username}/playlists/nonexistent-slug", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'party visibility inside a playlist' do
    # The playlist belongs to `user`; the party belongs to `party_owner` and
    # goes private after it was added.
    let(:party_owner) { create(:user) }
    let!(:playlist) { create(:playlist, user: user, visibility: 1) }
    let!(:shown_party) { create(:party, user: user, visibility: 1, raid: create(:raid)) }
    let!(:hidden_party) { create(:party, user: party_owner, visibility: 1, raid: create(:raid)) }

    def headers_for(viewer)
      token = Doorkeeper::AccessToken.create!(resource_owner_id: viewer.id, expires_in: 30.days, scopes: 'public')
      { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
    end

    before do
      create(:playlist_party, playlist: playlist, party: shown_party)
      create(:playlist_party, playlist: playlist, party: hidden_party)
      hidden_party.update!(visibility: 3)
    end

    it 'leaves the private party out for other viewers on show' do
      [nil, user, other_user].each do |viewer|
        get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}",
            headers: viewer ? headers_for(viewer) : unauth_headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body['playlist']
        expect(body['party_ids']).to eq([shown_party.id])
        expect(body['party_count']).to eq(1)
        expect(body['parties'].map { |p| p['id'] }).to eq([shown_party.id])
        expect(body['raid_slugs']).to eq([shown_party.raid.slug])
      end
    end

    it 'leaves the private party out for other viewers on index' do
      get "/api/v1/users/#{user.username}/playlists", headers: headers_for(other_user)

      result = response.parsed_body['results'].find { |p| p['id'] == playlist.id }
      expect(result['party_ids']).to eq([shown_party.id])
      expect(result['party_count']).to eq(1)
      expect(result['raid_slugs']).to eq([shown_party.raid.slug])
    end

    it "keeps the private party for the party's owner" do
      get "/api/v1/users/#{user.username}/playlists/#{playlist.slug}", headers: headers_for(party_owner)

      body = response.parsed_body['playlist']
      expect(body['party_ids']).to contain_exactly(shown_party.id, hidden_party.id)
      expect(body['party_count']).to eq(2)
      expect(body['parties'].map { |p| p['id'] }).to contain_exactly(shown_party.id, hidden_party.id)

      get "/api/v1/users/#{user.username}/playlists", headers: headers_for(party_owner)
      result = response.parsed_body['results'].find { |p| p['id'] == playlist.id }
      expect(result['party_count']).to eq(2)
      expect(result['raid_slugs']).to contain_exactly(shown_party.raid.slug, hidden_party.raid.slug)
    end

    it 'filters the playlist returned after an update' do
      patch "/api/v1/playlists/#{playlist.id}",
            params: { playlist: { title: 'Renamed' } }.to_json,
            headers: auth_headers

      expect(response.parsed_body.dig('playlist', 'party_ids')).to eq([shown_party.id])
    end
  end

  describe 'POST /api/v1/playlists' do
    let(:valid_params) { { playlist: { title: 'My Playlist', description: 'A description' } } }

    it 'creates a playlist and returns 201' do
      expect {
        post '/api/v1/playlists', params: valid_params.to_json, headers: auth_headers
      }.to change(Playlist, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('playlist', 'title')).to eq('My Playlist')
      expect(response.parsed_body.dig('playlist', 'slug')).to eq('my-playlist')
    end

    it 'rejects missing title with 422' do
      expect {
        post '/api/v1/playlists', params: { playlist: { description: 'No title' } }.to_json, headers: auth_headers
      }.not_to change(Playlist, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects duplicate title for same user with 422' do
      create(:playlist, user: user, title: 'Duplicate')

      expect {
        post '/api/v1/playlists', params: { playlist: { title: 'Duplicate' } }.to_json, headers: auth_headers
      }.not_to change(Playlist, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 without authentication' do
      post '/api/v1/playlists', params: valid_params.to_json, headers: unauth_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/playlists/:id' do
    let!(:playlist) { create(:playlist, user: user, title: 'Old Title') }

    it 'updates the playlist' do
      patch "/api/v1/playlists/#{playlist.id}",
            params: { playlist: { title: 'New Title', visibility: 2 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('playlist', 'title')).to eq('New Title')
      expect(playlist.reload.visibility).to eq(2)
    end

    it 'returns 401 for non-owner' do
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      patch "/api/v1/playlists/#{playlist.id}",
            params: { playlist: { title: 'Hijacked' } }.to_json,
            headers: other_headers

      expect(response).to have_http_status(:unauthorized)
      expect(playlist.reload.title).to eq('Old Title')
    end

    it 'rejects invalid visibility with 422' do
      patch "/api/v1/playlists/#{playlist.id}",
            params: { playlist: { visibility: 99 } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/playlists/:id' do
    let!(:playlist) { create(:playlist, user: user) }

    it 'deletes the playlist and cascades playlist_parties' do
      create_list(:playlist_party, 2, playlist: playlist)

      expect {
        delete "/api/v1/playlists/#{playlist.id}", headers: auth_headers
      }.to change(Playlist, :count).by(-1)
        .and change(PlaylistParty, :count).by(-2)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 401 for non-owner' do
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      expect {
        delete "/api/v1/playlists/#{playlist.id}", headers: other_headers
      }.not_to change(Playlist, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
