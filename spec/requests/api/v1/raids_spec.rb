# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Raids', type: :request do
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

  describe 'GET /api/v1/raids' do
    let!(:group) { create(:raid_group) }
    let!(:raid1) { create(:raid, group: group, element: 1) }
    let!(:raid2) { create(:raid, group: group, element: 2) }

    it 'returns all raids' do
      get '/api/v1/raids'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 2
    end

    it 'filters by element' do
      get '/api/v1/raids', params: { element: 1 }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 1
    end

    it 'filters by group_id' do
      get '/api/v1/raids', params: { group_id: group.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 2
    end
  end

  describe 'GET /api/v1/raids/:id' do
    let!(:raid) { create(:raid) }

    it 'returns the raid by slug' do
      get "/api/v1/raids/#{raid.slug}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns the raid by id' do
      get "/api/v1/raids/#{raid.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/raids' do
    let!(:group) { create(:raid_group) }
    let(:valid_params) do
      {
        raid: {
          name_en: 'Proto Bahamut', name_jp: 'プロトバハムート',
          slug: 'proto-bahamut', level: 150, element: 0, group_id: group.id
        }
      }
    end

    it 'creates a raid as editor' do
      post '/api/v1/raids', params: valid_params.to_json, headers: editor_headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/raids', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/raids/:id' do
    let!(:raid) { create(:raid) }

    it 'updates a raid as editor' do
      put "/api/v1/raids/#{raid.id}",
          params: { raid: { level: 200 } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects update by regular user' do
      put "/api/v1/raids/#{raid.id}",
          params: { raid: { level: 200 } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/raids/:id' do
    it 'deletes a raid without dependencies' do
      raid = create(:raid)
      delete "/api/v1/raids/#{raid.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion when parties exist' do
      raid = create(:raid)
      create(:party, raid: raid)
      delete "/api/v1/raids/#{raid.id}", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']['code']).to eq('has_dependencies')
    end

    it 'rejects deletion by regular user' do
      raid = create(:raid)
      delete "/api/v1/raids/#{raid.id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
