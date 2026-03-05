# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponSkillData', type: :request do
  let!(:datum1) { create(:weapon_skill_datum) }
  let!(:datum2) { create(:weapon_skill_datum) }

  describe 'GET /api/v1/weapon_skill_data' do
    it 'returns all weapon skill data' do
      get '/api/v1/weapon_skill_data'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['weapon_skill_data'].length).to be >= 2
    end

    it 'filters by modifier' do
      get '/api/v1/weapon_skill_data', params: { modifier: datum1.modifier }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/weapon_skill_data/:id' do
    it 'returns the weapon skill datum' do
      get "/api/v1/weapon_skill_data/#{datum1.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/weapon_skill_data/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end
end
