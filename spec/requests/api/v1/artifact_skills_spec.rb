# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Artifact Skills API', type: :request do
  before do
    # Create test skills in different groups
    create(:artifact_skill, :group_i, :atk, modifier: 1)
    create(:artifact_skill, :group_i, :hp, modifier: 2)
    create(:artifact_skill, :group_ii, modifier: 1, name_en: 'C.A. DMG', name_jp: '奥義ダメ')
    create(:artifact_skill, :group_iii, modifier: 1, name_en: 'Chain Burst DMG', name_jp: 'チェインダメ')
  end

  describe 'GET /api/v1/artifact_skills' do
    it 'returns all artifact skills' do
      get '/api/v1/artifact_skills'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].length).to eq(4)
    end

    it 'filters by skill group' do
      get '/api/v1/artifact_skills', params: { group: 'group_i' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].length).to eq(2)
      expect(json['artifact_skills'].all? { |s| s['skill_group'] == 'group_i' }).to be true
    end

    it 'filters by polarity' do
      create(:artifact_skill, :group_i, :negative, modifier: 99)

      get '/api/v1/artifact_skills', params: { polarity: 'negative' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].all? { |s| s['polarity'] == 'negative' }).to be true
    end
  end

  describe 'GET /api/v1/artifact_skills/for_slot/:slot' do
    it 'returns Group I skills for slot 1' do
      get '/api/v1/artifact_skills/for_slot/1'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].all? { |s| s['skill_group'] == 'group_i' }).to be true
    end

    it 'returns Group I skills for slot 2' do
      get '/api/v1/artifact_skills/for_slot/2'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].all? { |s| s['skill_group'] == 'group_i' }).to be true
    end

    it 'returns Group II skills for slot 3' do
      get '/api/v1/artifact_skills/for_slot/3'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].all? { |s| s['skill_group'] == 'group_ii' }).to be true
    end

    it 'returns Group III skills for slot 4' do
      get '/api/v1/artifact_skills/for_slot/4'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifact_skills'].all? { |s| s['skill_group'] == 'group_iii' }).to be true
    end

    it 'returns error for invalid slot' do
      get '/api/v1/artifact_skills/for_slot/5'

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['error']).to include('Slot must be between 1 and 4')
    end

    it 'returns error for slot 0' do
      get '/api/v1/artifact_skills/for_slot/0'

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
