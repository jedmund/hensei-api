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
  describe 'PATCH /api/v1/artifact_skills/:id' do
    let(:skill) { ArtifactSkill.find_by!(skill_group: :group_i, modifier: 1) }
    let(:path) { "/api/v1/artifact_skills/#{skill.id}" }

    def auth_headers(account)
      token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
      { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
    end

    let(:editor_headers) { auth_headers(create(:user, role: 7)) }

    it 'lets an editor change the permitted fields' do
      patch path, params: { name_en: 'Attack', game_name_en: 'ATK Up', growth: 250, polarity: 'negative',
                            base_values: [1, 2.5, 3], suffix_en: '%' }.to_json, headers: editor_headers

      expect(response).to have_http_status(:ok)
      skill.reload
      expect(skill).to have_attributes(name_en: 'Attack', game_name_en: 'ATK Up', polarity: 'negative',
                                       base_values: [1, 2.5, 3], suffix_en: '%')
      expect(skill.growth).to eq(250)
    end

    it 'ignores the group and modifier, which saved artifacts store skills by' do
      patch path, params: { skill_group: 'group_iii', modifier: 40, name_en: 'Attack' }.to_json,
                  headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(skill.reload).to have_attributes(skill_group: 'group_i', modifier: 1, name_en: 'Attack')
    end

    it 'ignores the score category, which comes from imports' do
      patch path, params: { score_category: 3 }.to_json, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(skill.reload.score_category).to be_nil
    end

    it 'answers invalid values with 422 and field errors' do
      patch path, params: { polarity: 'neutral', base_values: [1, 'two'], growth: 'fast' }.to_json,
                  headers: editor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].keys).to include('polarity', 'base_values', 'growth')
      expect(skill.reload.name_en).to eq('ATK')
    end

    # Rails' deep_munge compacts arrays in JSON params, so a null can't be
    # sent in place: the editor sends quality tiers with no gaps instead.
    it 'drops nulls from base values, as Rails does for every JSON array' do
      patch path, params: { base_values: [1, nil, 3] }.to_json, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(skill.reload.base_values).to eq([1, 3])
    end

    it 'rejects a user below the editor role' do
      patch path, params: { name_en: 'Hijacked' }.to_json, headers: auth_headers(create(:user, role: 3))

      expect(response).to have_http_status(:unauthorized)
      expect(skill.reload.name_en).to eq('ATK')
    end

    it 'rejects a signed-out request' do
      patch path, params: { name_en: 'Hijacked' }.to_json, headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(skill.reload.name_en).to eq('ATK')
    end
  end
end
