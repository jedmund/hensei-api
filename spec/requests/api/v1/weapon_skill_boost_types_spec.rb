# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponSkillBoostTypes', type: :request do
  let!(:offensive_boost_type) { create(:weapon_skill_boost_type, :offensive, :with_cap) }
  let!(:defensive_boost_type) { create(:weapon_skill_boost_type, :defensive) }

  describe 'GET /api/v1/weapon_skill_boost_types' do
    it 'returns all boost types with correct fields' do
      get '/api/v1/weapon_skill_boost_types'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_boost_types']
      expect(json.length).to be >= 2

      entry = json.find { |bt| bt['id'] == offensive_boost_type.id }
      expect(entry['key']).to eq(offensive_boost_type.key)
      expect(entry['name']['en']).to eq(offensive_boost_type.name_en)
      expect(entry['category']).to eq('offensive')
      expect(entry['stacking_rule']).to eq(offensive_boost_type.stacking_rule)
      expect(entry['grid_cap']).to eq(30.0)
      expect(entry['cap_is_flat']).to be(false)
    end

    it 'filters by category and excludes non-matching' do
      get '/api/v1/weapon_skill_boost_types', params: { category: 'offensive' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_boost_types']
      json.each do |bt|
        expect(bt['category']).to eq('offensive')
      end
      ids = json.pluck('id')
      expect(ids).to include(offensive_boost_type.id)
      expect(ids).not_to include(defensive_boost_type.id)
    end
  end

  describe 'GET /api/v1/weapon_skill_boost_types/:id' do
    it 'returns the correct boost type' do
      get "/api/v1/weapon_skill_boost_types/#{offensive_boost_type.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(offensive_boost_type.id)
      expect(json['key']).to eq(offensive_boost_type.key)
      expect(json['category']).to eq('offensive')
      expect(json['grid_cap']).to eq(30.0)
    end
  end
end
