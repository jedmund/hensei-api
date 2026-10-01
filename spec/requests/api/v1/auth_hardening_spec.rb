# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API auth hardening', type: :request do
  let(:user) { create(:user) }

  def auth_headers(token)
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'dead tokens' do
    let(:party) { create(:party, user: user) }

    it 'treats a revoked token as anonymous' do
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
      token.revoke

      put "/api/v1/parties/#{party.id}",
          params: { party: { name: 'Changed' } }.to_json,
          headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
      expect(party.reload.name).not_to eq('Changed')
    end

    it 'treats an expired token as anonymous' do
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 1.hour, scopes: 'public')
      token.update_column(:created_at, 2.hours.ago)

      put "/api/v1/parties/#{party.id}",
          params: { party: { name: 'Changed' } }.to_json,
          headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
      expect(party.reload.name).not_to eq('Changed')
    end
  end

  describe 'POST /api/v1/parties' do
    it 'ignores a user_id supplied by an anonymous request' do
      post '/api/v1/parties',
           params: { party: { name: 'Planted', user_id: user.id } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:created)
      expect(Party.find_by(name: 'Planted').user_id).to be_nil
    end
  end

  describe 'PUT /api/v1/parties/:id' do
    it 'does not let the owner reassign the party to another user' do
      party = create(:party, user: user)
      other = create(:user)
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')

      put "/api/v1/parties/#{party.id}",
          params: { party: { user_id: other.id } }.to_json,
          headers: auth_headers(token)
      expect(party.reload.user_id).to eq(user.id)
    end
  end

  describe 'POST /api/v1/parties/:id/unlink_collection' do
    it 'rejects anonymous requests on anonymous parties' do
      party = create(:party, user: nil, collection_source_user_id: user.id)

      post "/api/v1/parties/#{party.id}/unlink_collection", headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
      expect(party.reload.collection_source_user_id).to eq(user.id)
    end
  end

  describe 'rate limiting' do
    it 'limits password logins per email' do
      10.times do
        post '/oauth/token', params: { grant_type: 'password', email: user.email, password: 'wrong' }
        expect(response.status).not_to eq(429)
      end

      post '/oauth/token', params: { grant_type: 'password', email: user.email.upcase, password: 'wrong' }
      expect(response).to have_http_status(:too_many_requests)

      post '/oauth/token', params: { grant_type: 'password', email: 'someone-else@example.com', password: 'wrong' }
      expect(response.status).not_to eq(429)
    end

    it 'does not count refresh token requests against the login limit' do
      11.times { post '/oauth/token', params: { grant_type: 'refresh_token', refresh_token: 'nope', email: user.email } }
      expect(response.status).not_to eq(429)
    end

    it 'limits password reset requests per email' do
      5.times { post '/api/v1/password_resets', params: { email: user.email } }
      expect(response).to have_http_status(:ok)

      post '/api/v1/password_resets', params: { email: user.email }
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'limits availability checks per IP without sharing the signup counter' do
      30.times { post '/api/v1/check/username', params: { username: 'someone' } }
      expect(response.status).not_to eq(429)

      post '/api/v1/check/email', params: { email: 'a@example.com' }
      expect(response).to have_http_status(:too_many_requests)

      post '/api/v1/users', params: { user: { username: 'ratelimited', email: 'rl@example.com',
                                              password: 'password123', password_confirmation: 'password123' } }
      expect(response.status).not_to eq(429)
    end
  end

  describe 'artifact image downloads' do
    let(:artifact) { create(:artifact) }

    it 'rejects non-editors' do
      token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')

      post "/api/v1/artifacts/#{artifact.id}/download_image",
           params: { size: 'square' }.to_json,
           headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/artifacts/#{artifact.id}/download_images", headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects anonymous requests' do
      post "/api/v1/artifacts/#{artifact.id}/download_images",
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
