# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponSkillData', type: :request do
  let!(:normal_datum) { create(:weapon_skill_datum, series: 'normal', size: 'big') }
  let!(:omega_datum) { create(:weapon_skill_datum, series: 'omega', size: 'small') }

  describe 'GET /api/v1/weapon_skill_data' do
    it 'returns all weapon skill data with correct fields' do
      get '/api/v1/weapon_skill_data'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      expect(json.length).to be >= 2

      entry = json.find { |d| d['id'] == normal_datum.id }
      expect(entry['modifier']).to eq(normal_datum.modifier)
      expect(entry['boost_type']).to eq(normal_datum.boost_type)
      expect(entry['series']).to eq('normal')
      expect(entry['size']).to eq('big')
      expect(entry['formula_type']).to eq(normal_datum.formula_type)
      expect(entry['sl1']).to eq(normal_datum.sl1.to_f)
      expect(entry['sl10']).to eq(normal_datum.sl10.to_f)
      expect(entry['aura_boostable']).to eq(normal_datum.aura_boostable)
    end

    it 'filters by modifier and excludes non-matching' do
      get '/api/v1/weapon_skill_data', params: { modifier: normal_datum.modifier }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      json.each do |d|
        expect(d['modifier']).to eq(normal_datum.modifier)
      end
      ids = json.map { |d| d['id'] }
      expect(ids).to include(normal_datum.id)
      expect(ids).not_to include(omega_datum.id)
    end

    it 'filters by series' do
      get '/api/v1/weapon_skill_data', params: { series: 'omega' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      json.each do |d|
        expect(d['series']).to eq('omega')
      end
      ids = json.map { |d| d['id'] }
      expect(ids).to include(omega_datum.id)
      expect(ids).not_to include(normal_datum.id)
    end

    it 'filters by size' do
      get '/api/v1/weapon_skill_data', params: { size: 'big' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      json.each do |d|
        expect(d['size']).to eq('big')
      end
    end
  end

  describe 'GET /api/v1/weapon_skill_data/:id' do
    it 'returns the correct weapon skill datum' do
      get "/api/v1/weapon_skill_data/#{normal_datum.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(normal_datum.id)
      expect(json['modifier']).to eq(normal_datum.modifier)
      expect(json['boost_type']).to eq(normal_datum.boost_type)
      expect(json['series']).to eq(normal_datum.series)
      expect(json['size']).to eq(normal_datum.size)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/weapon_skill_data/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end
end
