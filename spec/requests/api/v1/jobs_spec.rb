# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Jobs', type: :request do
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

  describe 'GET /api/v1/jobs' do
    it 'returns all jobs with correct fields' do
      job = create(:job)
      get '/api/v1/jobs'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 1

      entry = json.find { |j| j['id'] == job.id }
      expect(entry['name']['en']).to eq(job.name_en)
      expect(entry['granblue_id']).to eq(job.granblue_id)
      expect(entry['row']).to eq(job.row)
    end
  end

  describe 'GET /api/v1/jobs/:id' do
    let!(:job) { create(:job) }

    it 'returns the job by granblue_id with correct fields' do
      get "/api/v1/jobs/#{job.granblue_id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(job.id)
      expect(json['name']['en']).to eq(job.name_en)
      expect(json['granblue_id']).to eq(job.granblue_id)
    end
  end

  describe 'POST /api/v1/jobs' do
    let(:valid_params) do
      {
        name_en: 'New Job', name_jp: '新ジョブ', granblue_id: '399999999',
        row: '4', order: 99, proficiency1: 1, master_level: 30
      }
    end

    it 'creates a job as editor and returns it' do
      expect {
        post '/api/v1/jobs', params: valid_params.to_json, headers: editor_headers
      }.to change(Job, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['name']['en']).to eq('New Job')
      expect(json['granblue_id']).to eq('399999999')
    end

    it 'rejects creation by regular user' do
      post '/api/v1/jobs', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/jobs/:id' do
    let!(:job) { create(:job) }

    it 'updates a job as editor and persists changes' do
      put "/api/v1/jobs/#{job.granblue_id}",
          params: { name_en: 'Updated Job' }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']['en']).to eq('Updated Job')
      expect(job.reload.name_en).to eq('Updated Job')
    end

    it 'rejects update by regular user' do
      put "/api/v1/jobs/#{job.granblue_id}",
          params: { name_en: 'Updated Job' }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
