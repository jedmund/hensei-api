# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::JobAccessories', type: :request do
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

  describe 'GET /api/v1/job_accessories' do
    let!(:accessory1) { create(:job_accessory, accessory_type: 1) }
    let!(:accessory2) { create(:job_accessory, accessory_type: 2) }

    it 'returns all accessories with correct fields' do
      get '/api/v1/job_accessories'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      entry = json.find { |a| a['id'] == accessory1.id }
      expect(entry['name']['en']).to eq(accessory1.name_en)
      expect(entry['granblue_id']).to eq(accessory1.granblue_id)
      expect(entry['accessory_type']).to eq(1)
    end

    it 'filters by accessory_type and excludes non-matching' do
      get '/api/v1/job_accessories', params: { accessory_type: 1 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |a|
        expect(a['accessory_type']).to eq(1)
      end
      ids = json.map { |a| a['id'] }
      expect(ids).to include(accessory1.id)
      expect(ids).not_to include(accessory2.id)
    end
  end

  describe 'GET /api/v1/job_accessories/:id' do
    let!(:accessory) { create(:job_accessory) }

    it 'returns the accessory by granblue_id with correct fields' do
      get "/api/v1/job_accessories/#{accessory.granblue_id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(accessory.id)
      expect(json['name']['en']).to eq(accessory.name_en)
      expect(json['granblue_id']).to eq(accessory.granblue_id)
    end

    it 'returns the accessory by uuid' do
      get "/api/v1/job_accessories/#{accessory.id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(accessory.id)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/job_accessories/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/job_accessories' do
    let!(:job) { create(:job) }
    let(:valid_params) do
      {
        name_en: 'New Accessory', name_jp: '新アクセサリー',
        granblue_id: '199999999', accessory_type: 1, job_id: job.id
      }
    end

    it 'creates an accessory as editor and returns it' do
      expect {
        post '/api/v1/job_accessories', params: valid_params.to_json, headers: editor_headers
      }.to change(JobAccessory, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['name']['en']).to eq('New Accessory')
      expect(json['granblue_id']).to eq('199999999')
    end

    it 'rejects creation by regular user' do
      expect {
        post '/api/v1/job_accessories', params: valid_params.to_json, headers: user_headers
      }.not_to change(JobAccessory, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/job_accessories/:id' do
    let!(:accessory) { create(:job_accessory) }

    it 'updates an accessory as editor and persists changes' do
      put "/api/v1/job_accessories/#{accessory.granblue_id}",
          params: { name_en: 'Updated Accessory' }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']['en']).to eq('Updated Accessory')
      expect(accessory.reload.name_en).to eq('Updated Accessory')
    end

    it 'rejects update by regular user' do
      put "/api/v1/job_accessories/#{accessory.granblue_id}",
          params: { name_en: 'Updated Accessory' }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
      expect(accessory.reload.name_en).not_to eq('Updated Accessory')
    end
  end

  describe 'DELETE /api/v1/job_accessories/:id' do
    it 'deletes an accessory as editor' do
      accessory = create(:job_accessory)
      expect {
        delete "/api/v1/job_accessories/#{accessory.granblue_id}", headers: editor_headers
      }.to change(JobAccessory, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion by regular user' do
      accessory = create(:job_accessory)
      expect {
        delete "/api/v1/job_accessories/#{accessory.granblue_id}", headers: user_headers
      }.not_to change(JobAccessory, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/jobs/:id/accessories' do
    let!(:job) { create(:job) }
    let!(:accessory) { create(:job_accessory, job: job) }

    it 'returns accessories for a job with correct data' do
      get "/api/v1/jobs/#{job.granblue_id}/accessories"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json.first['id']).to eq(accessory.id)
      expect(json.first['name']['en']).to eq(accessory.name_en)
    end
  end
end
