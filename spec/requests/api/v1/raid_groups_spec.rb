# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::RaidGroups', type: :request do
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

  describe 'GET /api/v1/raid_groups' do
    it 'returns all raid groups' do
      create(:raid_group)
      get '/api/v1/raid_groups'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 1
    end
  end

  describe 'GET /api/v1/raid_groups/:id' do
    let!(:group) { create(:raid_group) }

    it 'returns the raid group' do
      get "/api/v1/raid_groups/#{group.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns not found for invalid id' do
      get '/api/v1/raid_groups/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/raid_groups' do
    let(:valid_params) do
      {
        raid_group: {
          name_en: 'New Group', name_jp: '新グループ',
          order: 99, section: 1, hl: true
        }
      }
    end

    it 'creates a raid group as editor' do
      post '/api/v1/raid_groups', params: valid_params.to_json, headers: editor_headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/raid_groups', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/raid_groups/:id' do
    let!(:group) { create(:raid_group) }

    it 'updates a raid group as editor' do
      put "/api/v1/raid_groups/#{group.id}",
          params: { raid_group: { name_en: 'Updated Group' } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects update by regular user' do
      put "/api/v1/raid_groups/#{group.id}",
          params: { raid_group: { name_en: 'Updated Group' } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/raid_groups/:id' do
    it 'deletes a group without dependencies' do
      group = create(:raid_group)
      delete "/api/v1/raid_groups/#{group.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion when raids exist' do
      group = create(:raid_group)
      create(:raid, group: group)
      delete "/api/v1/raid_groups/#{group.id}", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']['code']).to eq('has_dependencies')
    end

    it 'rejects deletion by regular user' do
      group = create(:raid_group)
      delete "/api/v1/raid_groups/#{group.id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
