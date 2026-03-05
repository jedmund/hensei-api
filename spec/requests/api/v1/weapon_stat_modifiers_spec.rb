# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponStatModifiers', type: :request do
  let!(:modifier1) { create(:weapon_stat_modifier) }
  let!(:modifier2) { create(:weapon_stat_modifier) }

  describe 'GET /api/v1/weapon_stat_modifiers' do
    it 'returns all stat modifiers' do
      get '/api/v1/weapon_stat_modifiers'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['weapon_stat_modifiers'].length).to be >= 2
    end

    it 'filters by category' do
      get '/api/v1/weapon_stat_modifiers', params: { category: modifier1.category }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /api/v1/weapon_stat_modifiers/:id' do
    it 'returns the stat modifier' do
      get "/api/v1/weapon_stat_modifiers/#{modifier1.id}"
      expect(response).to have_http_status(:ok)
    end
  end
end
