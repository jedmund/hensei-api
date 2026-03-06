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

    it 'returns all accessories' do
      get '/api/v1/job_accessories'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 2
    end

    it 'filters by accessory_type' do
      get '/api/v1/job_accessories', params: { accessory_type: 1 }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 1
    end
  end

  describe 'GET /api/v1/job_accessories/:id' do
    let!(:accessory) { create(:job_accessory) }

    it 'returns the accessory by granblue_id' do
      get "/api/v1/job_accessories/#{accessory.granblue_id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns the accessory by uuid' do
      get "/api/v1/job_accessories/#{accessory.id}"
      expect(response).to have_http_status(:ok)
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

    it 'creates an accessory as editor' do
      post '/api/v1/job_accessories', params: valid_params.to_json, headers: editor_headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by regular user' do
      post '/api/v1/job_accessories', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/job_accessories/:id' do
    let!(:accessory) { create(:job_accessory) }

    it 'updates an accessory as editor' do
      put "/api/v1/job_accessories/#{accessory.granblue_id}",
          params: { name_en: 'Updated Accessory' }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects update by regular user' do
      put "/api/v1/job_accessories/#{accessory.granblue_id}",
          params: { name_en: 'Updated Accessory' }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/job_accessories/:id' do
    it 'deletes an accessory as editor' do
      accessory = create(:job_accessory)
      delete "/api/v1/job_accessories/#{accessory.granblue_id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion by regular user' do
      accessory = create(:job_accessory)
      delete "/api/v1/job_accessories/#{accessory.granblue_id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/jobs/:id/accessories' do
    let!(:job) { create(:job) }
    let!(:accessory) { create(:job_accessory, job: job) }

    it 'returns accessories for a job' do
      get "/api/v1/jobs/#{job.granblue_id}/accessories"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
    end
  end
end
