# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::SummonSeries', type: :request do
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

  describe 'GET /api/v1/summon_series' do
    it 'returns all summon series' do
      create(:summon_series)
      get '/api/v1/summon_series'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 1
    end
  end

  describe 'GET /api/v1/summon_series/:id' do
    let!(:series) { create(:summon_series) }

    it 'returns the series by id' do
      get "/api/v1/summon_series/#{series.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns the series by slug' do
      get "/api/v1/summon_series/#{series.slug}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/summon_series' do
    let(:valid_params) do
      { summon_series: { name_en: 'New Series', name_jp: '新シリーズ', slug: 'new-summon-series', order: 99 } }
    end

    it 'creates a series as editor' do
      post '/api/v1/summon_series', params: valid_params.to_json, headers: editor_headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/summon_series', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/summon_series/:id' do
    let!(:series) { create(:summon_series) }

    it 'updates a series as editor' do
      put "/api/v1/summon_series/#{series.id}",
          params: { summon_series: { name_en: 'Updated' } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']['en']).to eq('Updated')
    end

    it 'rejects update by regular user' do
      put "/api/v1/summon_series/#{series.id}",
          params: { summon_series: { name_en: 'Updated' } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/summon_series/:id' do
    it 'deletes a series without dependencies' do
      series = create(:summon_series)
      delete "/api/v1/summon_series/#{series.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion when summons exist' do
      series = create(:summon_series)
      create(:summon, summon_series: series)
      delete "/api/v1/summon_series/#{series.id}", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']['code']).to eq('has_dependencies')
    end

    it 'rejects deletion by regular user' do
      series = create(:summon_series)
      delete "/api/v1/summon_series/#{series.id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
