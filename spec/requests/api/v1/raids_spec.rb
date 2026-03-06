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

    it 'returns all raids with correct fields' do
      get '/api/v1/raids'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      entry = json.find { |r| r['id'] == raid1.id }
      expect(entry['name']['en']).to eq(raid1.name_en)
      expect(entry['slug']).to eq(raid1.slug)
      expect(entry['level']).to eq(raid1.level)
      expect(entry['element']).to eq(raid1.element)
    end

    it 'filters by element and excludes non-matching' do
      get '/api/v1/raids', params: { element: 1 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |r|
        expect(r['element']).to eq(1)
      end
      ids = json.map { |r| r['id'] }
      expect(ids).to include(raid1.id)
      expect(ids).not_to include(raid2.id)
    end

    it 'filters by group_id and excludes other groups' do
      other_group = create(:raid_group)
      other_raid = create(:raid, group: other_group)

      get '/api/v1/raids', params: { group_id: group.id }
      expect(response).to have_http_status(:ok)

      ids = response.parsed_body.map { |r| r['id'] }
      expect(ids).to include(raid1.id, raid2.id)
      expect(ids).not_to include(other_raid.id)
    end
  end

  describe 'GET /api/v1/raids/:id' do
    let!(:raid) { create(:raid) }

    it 'returns the raid by slug with correct fields' do
      get "/api/v1/raids/#{raid.slug}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(raid.id)
      expect(json['name']['en']).to eq(raid.name_en)
      expect(json['slug']).to eq(raid.slug)
    end

    it 'returns the raid by id' do
      get "/api/v1/raids/#{raid.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(raid.id)
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

    it 'creates a raid as editor and returns it' do
      expect {
        post '/api/v1/raids', params: valid_params.to_json, headers: editor_headers
      }.to change(Raid, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['name']['en']).to eq('Proto Bahamut')
      expect(json['slug']).to eq('proto-bahamut')
      expect(json['level']).to eq(150)
    end

    it 'rejects creation by regular user' do
      expect {
        post '/api/v1/raids', params: valid_params.to_json, headers: user_headers
      }.not_to change(Raid, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/raids/:id' do
    let!(:raid) { create(:raid) }

    it 'updates a raid as editor and persists changes' do
      put "/api/v1/raids/#{raid.id}",
          params: { raid: { level: 200 } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['level']).to eq(200)
      expect(raid.reload.level).to eq(200)
    end

    it 'rejects update by regular user' do
      put "/api/v1/raids/#{raid.id}",
          params: { raid: { level: 200 } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
      expect(raid.reload.level).not_to eq(200)
    end
  end

  describe 'DELETE /api/v1/raids/:id' do
    it 'deletes a raid without dependencies' do
      raid = create(:raid)
      expect {
        delete "/api/v1/raids/#{raid.id}", headers: editor_headers
      }.to change(Raid, :count).by(-1)
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
      expect {
        delete "/api/v1/raids/#{raid.id}", headers: user_headers
      }.not_to change(Raid, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
