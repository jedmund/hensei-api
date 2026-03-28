# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Roles API', type: :request do
  describe 'GET /api/v1/roles' do
    before do
      create(:role, name_en: 'Attacker', slot_type: 'Character', sort_order: 1)
      create(:role, :weapon, sort_order: 2)
      create(:role, :summon, sort_order: 3)
    end

    it 'returns all roles without auth' do
      get '/api/v1/roles'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
    end

    it 'filters by slot_type' do
      get '/api/v1/roles', params: { slot_type: 'Character' }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first['slot_type']).to eq('Character')
    end
  end
end
