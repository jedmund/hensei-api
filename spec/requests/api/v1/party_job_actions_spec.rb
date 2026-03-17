# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party Job Actions API', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:job) { create(:job) }
  let!(:party) { create(:party, user: user) }

  describe 'PUT /api/v1/parties/:id/jobs (update_job)' do
    it 'sets the job on the party and returns job metadata' do
      put "/api/v1/parties/#{party.shortcode}/jobs",
          params: { party: { job_id: job.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['job']['id']).to eq(job.id)
    end

    it 'populates main skills when setting a job that has them' do
      main_skill = create(:job_skill, :main_skill, job: job)

      put "/api/v1/parties/#{party.shortcode}/jobs",
          params: { party: { job_id: job.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['job_skills']['0']['id']).to eq(main_skill.id)
    end

    it 'returns unauthorized when party belongs to a different user' do
      other_party = create(:party, user: create(:user))

      put "/api/v1/parties/#{other_party.shortcode}/jobs",
          params: { party: { job_id: job.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when party does not exist' do
      put '/api/v1/parties/NOSUCH/jobs',
          params: { party: { job_id: job.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/parties/:id/job_skills (update_job_skills)' do
    let(:sub_skill) { create(:job_skill, :sub_skill, job: job) }

    before do
      party.update!(job: job)
    end

    it 'sets a skill at the given position and returns updated skills' do
      put "/api/v1/parties/#{party.shortcode}/job_skills",
          params: { party: { skill1_id: sub_skill.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['job_skills']['1']['id']).to eq(sub_skill.id)
    end

    it 'returns unauthorized when party belongs to a different user' do
      other_party = create(:party, user: create(:user), job: job)

      put "/api/v1/parties/#{other_party.shortcode}/job_skills",
          params: { party: { skill1_id: sub_skill.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when party does not exist' do
      put '/api/v1/parties/NOSUCH/job_skills',
          params: { party: { skill1_id: sub_skill.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/parties/:id/job_skills (destroy_job_skill)' do
    let(:sub_skill) { create(:job_skill, :sub_skill, job: job) }

    before do
      party.update!(job: job, skill1_id: sub_skill.id)
    end

    it 'clears the skill at the given position' do
      delete "/api/v1/parties/#{party.shortcode}/job_skills",
             params: { party: { skill_position: 1 } }.to_json,
             headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['job_skills']['1']).to be_nil
    end

    it 'returns unauthorized when party belongs to a different user' do
      other_party = create(:party, user: create(:user), job: job, skill1_id: sub_skill.id)

      delete "/api/v1/parties/#{other_party.shortcode}/job_skills",
             params: { party: { skill_position: 1 } }.to_json,
             headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when party does not exist' do
      delete '/api/v1/parties/NOSUCH/job_skills',
             params: { party: { skill_position: 1 } }.to_json,
             headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/parties/:id/accessory (update_accessory)' do
    let(:accessory) { create(:job_accessory, job: job) }

    before do
      party.update!(job: job)
    end

    it 'sets the accessory on the party and returns it in the response' do
      put "/api/v1/parties/#{party.shortcode}/accessory",
          params: { party: { accessory_id: accessory.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['accessory']['id']).to eq(accessory.id)
      expect(body['accessory']['name']['en']).to eq(accessory.name_en)
    end

    it 'returns unauthorized when party belongs to a different user' do
      other_party = create(:party, user: create(:user), job: job)

      put "/api/v1/parties/#{other_party.shortcode}/accessory",
          params: { party: { accessory_id: accessory.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when party does not exist' do
      put '/api/v1/parties/NOSUCH/accessory',
          params: { party: { accessory_id: accessory.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found when accessory does not exist' do
      put "/api/v1/parties/#{party.shortcode}/accessory",
          params: { party: { accessory_id: -1 } }.to_json,
          headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/parties/:id/accessory (destroy_accessory)' do
    let(:accessory) { create(:job_accessory, job: job) }

    before do
      party.update!(job: job, accessory: accessory)
    end

    it 'clears the accessory and returns nil accessory in the response' do
      delete "/api/v1/parties/#{party.shortcode}/accessory",
             headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['accessory']).to be_nil
      expect(party.reload.accessory).to be_nil
    end

    it 'returns unauthorized when party belongs to a different user' do
      other_party = create(:party, user: create(:user), job: job, accessory: accessory)

      delete "/api/v1/parties/#{other_party.shortcode}/accessory",
             headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found when party does not exist' do
      delete '/api/v1/parties/NOSUCH/accessory',
             headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
