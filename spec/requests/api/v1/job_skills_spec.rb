# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JobSkills API', type: :request do
  let(:editor_user) { create(:user, role: 7) }
  let(:regular_user) { create(:user, role: 3) }
  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:regular_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: regular_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:editor_headers) do
    { 'Authorization' => "Bearer #{editor_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:regular_headers) do
    { 'Authorization' => "Bearer #{regular_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:job) { create(:job) }

  describe 'GET /api/v1/jobs/skills' do
    let!(:skill1) { create(:job_skill, job: job) }
    let!(:skill2) { create(:job_skill, job: job) }

    it 'returns all job skills' do
      get '/api/v1/jobs/skills'
      expect(response).to have_http_status(:ok)

      skills = response.parsed_body
      expect(skills).to be_an(Array)
      expect(skills.length).to be >= 2
    end
  end

  describe 'GET /api/v1/jobs/:id/skills' do
    let!(:job_skill) { create(:job_skill, job: job, name_en: 'Rage') }
    let(:other_job) { create(:job) }
    let!(:other_skill) { create(:job_skill, job: other_job, name_en: 'Other') }

    it 'returns skills belonging to the specified job' do
      get "/api/v1/jobs/#{job.granblue_id}/skills"
      expect(response).to have_http_status(:ok)

      skills = response.parsed_body
      expect(skills).to be_an(Array)
      skill_names = skills.map { |s| s.dig('name', 'en') }
      expect(skill_names).to include('Rage')
      expect(skill_names).not_to include('Other')
    end

    it 'returns not found for a non-existent job' do
      get '/api/v1/jobs/999999/skills'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/jobs/:id/emp_skills' do
    let!(:emp_skill) { create(:job_skill, :emp_skill, job: job, name_en: 'EMP Skill') }
    let!(:non_emp_skill) { create(:job_skill, job: job, name_en: 'Regular Skill') }
    let(:other_job) { create(:job) }
    let!(:other_emp) { create(:job_skill, :emp_skill, job: other_job, name_en: 'Other EMP') }

    it 'returns EMP skills from other jobs, excluding the specified job' do
      get "/api/v1/jobs/#{job.id}/emp_skills"
      expect(response).to have_http_status(:ok)

      skills = response.parsed_body
      skill_names = skills.map { |s| s.dig('name', 'en') }
      expect(skill_names).to include('Other EMP')
      expect(skill_names).not_to include('EMP Skill')
      expect(skill_names).not_to include('Regular Skill')
    end
  end

  describe 'POST /api/v1/jobs/:job_id/skills' do
    let(:valid_params) do
      {
        name_en: 'New Skill',
        name_jp: '新スキル',
        slug: 'new-skill',
        color: 2,
        main: true,
        sub: false,
        emp: false,
        base: false,
        order: 1
      }
    end

    context 'as an editor' do
      it 'creates a new job skill' do
        expect {
          post "/api/v1/jobs/#{job.granblue_id}/skills", params: valid_params.to_json, headers: editor_headers
        }.to change(JobSkill, :count).by(1)
        expect(response).to have_http_status(:created)

        skill = response.parsed_body
        expect(skill.dig('name', 'en')).to eq('New Skill')
        expect(skill['slug']).to eq('new-skill')
        expect(skill['main']).to be true
      end

      it 'returns not found for a non-existent job' do
        post '/api/v1/jobs/999999/skills', params: valid_params.to_json, headers: editor_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as a regular user' do
      it 'returns unauthorized' do
        post "/api/v1/jobs/#{job.granblue_id}/skills", params: valid_params.to_json, headers: regular_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/jobs/:job_id/skills/:id' do
    let!(:skill) { create(:job_skill, job: job, name_en: 'Old Name') }

    context 'as an editor' do
      it 'updates the job skill' do
        put "/api/v1/jobs/#{job.granblue_id}/skills/#{skill.id}",
            params: { name_en: 'Updated Name' }.to_json,
            headers: editor_headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig('name', 'en')).to eq('Updated Name')
      end
    end

    context 'as a regular user' do
      it 'returns unauthorized' do
        put "/api/v1/jobs/#{job.granblue_id}/skills/#{skill.id}",
            params: { name_en: 'Updated Name' }.to_json,
            headers: regular_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/jobs/:job_id/skills/:id' do
    let!(:skill) { create(:job_skill, job: job) }

    context 'as an editor' do
      it 'destroys the job skill' do
        expect {
          delete "/api/v1/jobs/#{job.granblue_id}/skills/#{skill.id}", headers: editor_headers
        }.to change(JobSkill, :count).by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as a regular user' do
      it 'returns unauthorized' do
        delete "/api/v1/jobs/#{job.granblue_id}/skills/#{skill.id}", headers: regular_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
