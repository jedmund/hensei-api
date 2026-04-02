# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Users timezone', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 7200, scopes: '')
  end
  let(:auth_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{access_token.token}" }
  end

  describe 'PUT /api/v1/users/:id' do
    it 'persists a timezone value' do
      put "/api/v1/users/#{user.id}",
          params: { user: { timezone: 'Asia/Tokyo' } }.to_json,
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.timezone).to eq('Asia/Tokyo')
    end

    it 'updates timezone to a different value' do
      user.update!(timezone: 'UTC')

      put "/api/v1/users/#{user.id}",
          params: { user: { timezone: 'America/New_York' } }.to_json,
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.timezone).to eq('America/New_York')
    end

    it 'clears timezone when set to nil' do
      user.update!(timezone: 'Asia/Tokyo')

      put "/api/v1/users/#{user.id}",
          params: { user: { timezone: nil } }.to_json,
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.timezone).to be_nil
    end
  end

  describe 'GET /api/v1/users/me' do
    it 'includes timezone in the response' do
      user.update!(timezone: 'Europe/London')

      get '/api/v1/users/me', headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['timezone']).to eq('Europe/London')
    end

    it 'returns nil timezone when not set' do
      get '/api/v1/users/me', headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['timezone']).to be_nil
    end
  end
end
