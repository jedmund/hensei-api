# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponSkillBoostTypes', type: :request do
  let!(:boost_type1) { create(:weapon_skill_boost_type) }
  let!(:boost_type2) { create(:weapon_skill_boost_type) }

  describe 'GET /api/v1/weapon_skill_boost_types' do
    it 'returns all boost types' do
      get '/api/v1/weapon_skill_boost_types'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['weapon_skill_boost_types'].length).to be >= 2
    end

    it 'filters by category' do
      get '/api/v1/weapon_skill_boost_types', params: { category: boost_type1.category }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/weapon_skill_boost_types/:id' do
    it 'returns the boost type' do
      get "/api/v1/weapon_skill_boost_types/#{boost_type1.id}"
      expect(response).to have_http_status(:ok)
    end
  end
end
