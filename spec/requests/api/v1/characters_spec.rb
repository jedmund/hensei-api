# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Characters', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }
  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 30.days, scopes: 'public')
  end
  let(:user_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:editor_headers) do
    { 'Authorization' => "Bearer #{editor_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:user_headers) do
    { 'Authorization' => "Bearer #{user_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'GET /api/v1/characters/:id' do
    let!(:character) { create(:character) }

    it 'returns the character by uuid' do
      get "/api/v1/characters/#{character.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns the character by granblue_id' do
      get "/api/v1/characters/#{character.granblue_id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/characters/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/characters/:id/related' do
    it 'returns related characters with same character_id' do
      char1 = create(:character, character_id: %w[1234])
      create(:character, character_id: %w[1234])
      get "/api/v1/characters/#{char1.id}/related"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
    end

    it 'returns empty when no related characters exist' do
      char = create(:character, character_id: %w[9999])
      get "/api/v1/characters/#{char.id}/related"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  describe 'POST /api/v1/characters' do
    let(:valid_params) do
      {
        character: {
          granblue_id: '3040999000', name_en: 'Test Character', name_jp: 'テストキャラ',
          rarity: 3, element: 1, proficiency1: 1
        }
      }
    end

    it 'creates a character as editor' do
      post '/api/v1/characters', params: valid_params.to_json, headers: editor_headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/characters', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/characters/:id' do
    let!(:character) { create(:character) }

    it 'updates a character as editor' do
      put "/api/v1/characters/#{character.id}",
          params: { character: { name_en: 'Updated Name' } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects update by regular user' do
      put "/api/v1/characters/#{character.id}",
          params: { character: { name_en: 'Updated Name' } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/characters/:id/raw' do
    let!(:character) { create(:character) }

    it 'returns raw character data' do
      get "/api/v1/characters/#{character.id}/raw"
      expect(response).to have_http_status(:ok)
    end
  end
end
