# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Roles API', type: :request do
  let!(:char_role) { create(:role, name_en: 'Buffer', slot_type: 'Character', sort_order: 0) }
  let!(:weapon_role) { create(:role, name_en: 'Stat stick', slot_type: 'Weapon', sort_order: 0) }
  let!(:summon_role) { create(:role, name_en: 'Main aura', slot_type: 'Summon', sort_order: 0) }

  describe 'GET /roles' do
    it 'returns all roles without authentication' do
      get '/api/v1/roles'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['roles'].length).to eq(3)
    end

    it 'filters by slot_type' do
      get '/api/v1/roles', params: { slot_type: 'Character' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['roles'].length).to eq(1)
      expect(json['roles'][0]['name_en']).to eq('Buffer')
    end

    it 'returns empty array for unknown slot_type' do
      get '/api/v1/roles', params: { slot_type: 'Unknown' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['roles']).to be_empty
    end
  end
end
