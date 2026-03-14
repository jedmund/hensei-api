# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Roles API', type: :request do
  describe 'GET /api/v1/roles' do
    it 'returns all roles' do
      create(:role, name_en: 'Buffer', slot_type: 'Character')
      create(:role, :weapon)
      create(:role, :summon)

      get '/api/v1/roles'
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
    end

    it 'filters by slot_type' do
      create(:role, name_en: 'Buffer', slot_type: 'Character')
      create(:role, :weapon)

      get '/api/v1/roles', params: { slot_type: 'Character' }
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first['name_en']).to eq('Buffer')
    end

    it 'works without auth' do
      get '/api/v1/roles'
      expect(response).to have_http_status(:ok)
    end
  end
end
