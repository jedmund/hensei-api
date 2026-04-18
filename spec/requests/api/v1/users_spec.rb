# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/users' do
    it 'creates a user and returns a token' do
      post '/api/v1/users', params: {
        user: {
          email: 'newuser@example.com', password: 'password123',
          password_confirmation: 'password123', username: 'newuser'
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['token']).to be_present
    end
  end

  describe 'GET /api/v1/users/me' do
    it 'returns current user settings with correct fields' do
      get '/api/v1/users/me', headers: auth_headers
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(user.id)
      expect(json['username']).to eq(user.username)
      expect(json['email']).to eq(user.email)
    end

    it 'returns 401 without authentication' do
      get '/api/v1/users/me'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/users/info/:id' do
    it 'returns user info with correct fields' do
      get "/api/v1/users/info/#{user.username}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(user.id)
      expect(json['username']).to eq(user.username)
    end
  end

  describe 'GET /api/v1/users/:id' do
    it 'returns user profile with correct fields' do
      get "/api/v1/users/#{user.username}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['profile']
      expect(json['id']).to eq(user.id)
      expect(json['username']).to eq(user.username)
    end

    it 'returns 404 for non-existent user' do
      get '/api/v1/users/nonexistentuser999'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/users/:id' do
    it 'updates user settings and persists changes' do
      put "/api/v1/users/#{user.id}",
          params: { user: { language: 'ja' } }.to_json,
          headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.language).to eq('ja')
    end

    it 'persists a valid description' do
      put "/api/v1/users/#{user.id}",
          params: { user: { description: 'Fire team enjoyer.' } }.to_json,
          headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.description).to eq('Fire team enjoyer.')
    end

    it 'does not persist a description that fails profanity validation' do
      put "/api/v1/users/#{user.id}",
          params: { user: { description: 'hello asshole world' } }.to_json,
          headers: auth_headers
      expect(user.reload.description).to be_nil
    end

    it 'does not persist a description over 140 characters' do
      put "/api/v1/users/#{user.id}",
          params: { user: { description: 'a' * 141 } }.to_json,
          headers: auth_headers
      expect(user.reload.description).to be_nil
    end
  end

  describe 'GET /api/v1/users/info/:id description field' do
    it 'exposes description on the user info payload' do
      user.update!(description: 'Hello world')
      get "/api/v1/users/info/#{user.username}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['description']).to eq('Hello world')
    end
  end

  describe 'POST /api/v1/check/email' do
    it 'checks email availability' do
      post '/api/v1/check/email', params: { email: 'available@example.com' }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/check/username' do
    it 'checks username availability' do
      post '/api/v1/check/username', params: { username: 'availableuser' }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
    end
  end
end
