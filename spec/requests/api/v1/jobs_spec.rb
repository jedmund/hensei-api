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

    it 'returns the job by uuid, which tells apart jobs sharing a granblue_id' do
      successor = create(:job, granblue_id: job.granblue_id, row: '2')
      get "/api/v1/jobs/#{successor.id}"
      expect(response.parsed_body['id']).to eq(successor.id)
    end

    it 'returns not found for an unknown id' do
      get '/api/v1/jobs/999998'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/jobs' do
    let(:valid_params) do
      {
        name_en: 'New Job', name_jp: '新ジョブ', granblue_id: '399999',
        row: '4', order: 99, proficiency1: 1, proficiency2: 2, master_level: true
      }
    end

    it 'creates a job as editor and returns it' do
      expect {
        post '/api/v1/jobs', params: valid_params.to_json, headers: editor_headers
      }.to change(Job, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['name']['en']).to eq('New Job')
      expect(json['granblue_id']).to eq('399999')
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

    it 'updates the job named by uuid and writes aux_weapon' do
      successor = create(:job, granblue_id: job.granblue_id, row: '2')
      put "/api/v1/jobs/#{successor.id}", params: { aux_weapon: true }.to_json, headers: editor_headers
      expect(successor.reload.aux_weapon).to be true
      expect(job.reload.aux_weapon).to be false
    end

    it 'puts a new job without an order last in its row' do
      create(:job, row: '5', order: 7)
      post '/api/v1/jobs', params: { name_en: 'Late', name_jp: '後', granblue_id: '399998', row: '5',
                                     proficiency1: 1, proficiency2: 2 }.to_json, headers: editor_headers
      expect(response.parsed_body['order']).to eq(8)
    end

    it 'rejects an invalid job with 422' do
      put "/api/v1/jobs/#{job.id}", params: { row: 'ex', granblue_id: '12' }.to_json, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects update by regular user' do
      put "/api/v1/jobs/#{job.granblue_id}",
          params: { name_en: 'Updated Job' }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
