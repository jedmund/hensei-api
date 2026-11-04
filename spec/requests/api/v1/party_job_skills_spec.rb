# frozen_string_literal: true

require 'rails_helper'

# How PUT /parties/:id/jobs and PUT /parties/:id/job_skills fill, drop,
# merge and refuse a party's job skills.
RSpec.describe 'Party job skills', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end
  let!(:party) { create(:party, user: user) }
  let(:row_one) { create(:job, row: '1') }
  let(:row_four) { create(:job, row: '4') }

  def skill_ids
    response.parsed_body['job_skills'].transform_values { |skill| skill&.fetch('id') }
  end

  def assign_job(job_id)
    put "/api/v1/parties/#{party.shortcode}/jobs", params: { party: { job_id: job_id } }.to_json, headers: headers
  end

  def equip_skills(skills)
    put "/api/v1/parties/#{party.shortcode}/job_skills", params: { party: skills }.to_json, headers: headers
  end

  describe 'PUT /parties/:id/jobs' do
    it 'clears the job and every skill for job_id -1' do
      main = create(:job_skill, :main_skill, job: row_four)
      sub = create(:job_skill, :sub_skill, job: row_four)
      party.update!(job: row_four, skill0: main, skill1: sub)

      assign_job(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['job']).to be_nil
      expect(skill_ids).to eq('0' => nil, '1' => nil, '2' => nil, '3' => nil)
      expect(party.reload.last_updated).to be_present
    end

    it "drops skills the new job can't use and keeps the rest" do
      other_job = create(:job, row: '4', base_job: create(:job, row: '1'))
      emp = create(:job_skill, :emp_skill, job: other_job)
      sub = create(:job_skill, :sub_skill, job: other_job)
      main = create(:job_skill, :main_skill, job: row_four)
      party.update!(job: other_job, skill1: emp, skill2: sub)

      assign_job(row_four.id)

      expect(response).to have_http_status(:ok)
      expect(skill_ids).to eq('0' => main.id, '1' => nil, '2' => sub.id, '3' => nil)
    end

    it 'drops the third subskill moving from a row 1-3 job to a row 4 job' do
      subs = create_list(:job_skill, 3, :sub_skill, job: row_one)
      party.update!(job: row_one, skill1: subs[0], skill2: subs[1], skill3: subs[2])

      assign_job(row_four.id)

      expect(skill_ids).to eq('0' => nil, '1' => subs[0].id, '2' => subs[1].id, '3' => nil)
    end

    it 'keeps three subskills between row 4 jobs' do
      subs = create_list(:job_skill, 3, :sub_skill, job: row_one)
      party.update!(job: create(:job, row: '5'), skill1: subs[0], skill2: subs[1], skill3: subs[2])

      assign_job(row_four.id)

      expect(skill_ids).to eq('0' => nil, '1' => subs[0].id, '2' => subs[1].id, '3' => subs[2].id)
    end

    it 'returns 404 for an unknown job' do
      assign_job(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses an anonymous request' do
      put "/api/v1/parties/#{party.shortcode}/jobs", params: { party: { job_id: row_four.id } }.to_json,
                                                     headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(party.reload.job).to be_nil
    end
  end

  describe 'PUT /parties/:id/job_skills' do
    before { party.update!(job: row_four) }

    it 'refuses a request with no skill' do
      equip_skills(skill0_id: create(:job_skill, :main_skill, job: row_four).id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['code']).to eq('no_job_skill_provided')
    end

    it 'returns 404 for an unknown skill' do
      equip_skills(skill1_id: SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
    end

    it "refuses another job's main skill" do
      equip_skills(skill1_id: create(:job_skill, :main_skill, job: row_one).id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['code']).to eq('incompatible_skill')
    end

    it 'refuses a third subskill on a row 4 job' do
      subs = create_list(:job_skill, 3, :sub_skill, job: row_one)
      party.update!(skill1: subs[0], skill2: subs[1])

      equip_skills(skill3_id: subs[2].id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['code']).to eq('too_many_skills_of_type')
      expect(party.reload.skill3).to be_nil
    end

    it 'allows a third subskill on a row 1 job' do
      party.update!(job: row_one)
      subs = create_list(:job_skill, 3, :sub_skill, job: row_one)
      party.update!(skill1: subs[0], skill2: subs[1])

      equip_skills(skill3_id: subs[2].id)

      expect(response).to have_http_status(:ok)
      expect(skill_ids).to include('3' => subs[2].id)
    end

    it 'swaps a skill already equipped elsewhere' do
      first, second = create_list(:job_skill, 2, :emp_skill, job: row_four)
      party.update!(skill1: first, skill2: second)

      equip_skills(skill1_id: second.id)

      expect(response).to have_http_status(:ok)
      expect(skill_ids).to eq('0' => nil, '1' => second.id, '2' => first.id, '3' => nil)
    end

    it 'sets several skills at once' do
      emp = create(:job_skill, :emp_skill, job: row_four)
      sub = create(:job_skill, :sub_skill, job: row_one)

      equip_skills(skill2_id: emp.id, skill3_id: sub.id)

      expect(skill_ids).to eq('0' => nil, '1' => nil, '2' => emp.id, '3' => sub.id)
    end

    it "refuses someone else's party" do
      other = create(:party, user: create(:user), job: row_four)

      put "/api/v1/parties/#{other.shortcode}/job_skills",
          params: { party: { skill1_id: create(:job_skill, :emp_skill, job: row_four).id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
