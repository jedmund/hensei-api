# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Summons', type: :request do
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

  describe 'GET /api/v1/summons/:id' do
    let!(:summon) { create(:summon) }

    it 'returns the summon by uuid with correct fields' do
      get "/api/v1/summons/#{summon.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(summon.id)
      expect(json['name']['en']).to eq(summon.name_en)
      expect(json['granblue_id']).to eq(summon.granblue_id)
      expect(json['rarity']).to eq(summon.rarity)
      expect(json['element']).to eq(summon.element)
    end

    it 'returns the summon by granblue_id' do
      get "/api/v1/summons/#{summon.granblue_id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(summon.id)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/summons/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/summons' do
    let(:valid_params) do
      {
        summon: {
          granblue_id: '2040999000', name_en: 'Test Summon', name_jp: 'テスト召喚',
          rarity: 3, element: 1
        }
      }
    end

    it 'creates a summon as editor and returns it' do
      expect {
        post '/api/v1/summons', params: valid_params.to_json, headers: editor_headers
      }.to change(Summon, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['granblue_id']).to eq('2040999000')
      expect(json['name']['en']).to eq('Test Summon')
      expect(json['element']).to eq(1)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/summons', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/summons/:id' do
    let!(:summon) { create(:summon) }

    it 'updates a summon as editor and persists changes' do
      put "/api/v1/summons/#{summon.id}",
          params: { summon: { name_en: 'Updated Summon' } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']['en']).to eq('Updated Summon')
      expect(summon.reload.name_en).to eq('Updated Summon')
    end

    it 'rejects update by regular user' do
      put "/api/v1/summons/#{summon.id}",
          params: { summon: { name_en: 'Updated Summon' } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/summons/:id/raw' do
    let!(:summon) { create(:summon) }

    it 'returns raw summon data' do
      get "/api/v1/summons/#{summon.id}/raw"
      expect(response).to have_http_status(:ok)
    end
  end
end
