# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponSkillData', type: :request do
  let!(:datum1) { create(:weapon_skill_datum, series: 'normal', size: 'big') }
  let!(:datum2) { create(:weapon_skill_datum, series: 'omega', size: 'small') }

  describe 'GET /api/v1/weapon_skill_data' do
    it 'returns all weapon skill data with correct fields' do
      get '/api/v1/weapon_skill_data'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      expect(json.length).to be >= 2

      entry = json.find { |d| d['id'] == datum1.id }
      expect(entry['modifier']).to eq(datum1.modifier)
      expect(entry['boost_type']).to eq(datum1.boost_type)
      expect(entry['series']).to eq('normal')
      expect(entry['size']).to eq('big')
      expect(entry['formula_type']).to eq(datum1.formula_type)
      expect(entry['sl1']).to eq(datum1.sl1.to_f)
      expect(entry['sl10']).to eq(datum1.sl10.to_f)
      expect(entry['aura_boostable']).to eq(datum1.aura_boostable)
    end

    it 'filters by modifier and excludes non-matching' do
      get '/api/v1/weapon_skill_data', params: { modifier: datum1.modifier }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      json.each do |d|
        expect(d['modifier']).to eq(datum1.modifier)
      end
      ids = json.map { |d| d['id'] }
      expect(ids).to include(datum1.id)
      expect(ids).not_to include(datum2.id)
    end

    it 'filters by series' do
      get '/api/v1/weapon_skill_data', params: { series: 'omega' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_skill_data']
      json.each do |d|
        expect(d['series']).to eq('omega')
      end
      ids = json.map { |d| d['id'] }
      expect(ids).to include(datum2.id)
      expect(ids).not_to include(datum1.id)
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
      get "/api/v1/weapon_skill_data/#{datum1.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(datum1.id)
      expect(json['modifier']).to eq(datum1.modifier)
      expect(json['boost_type']).to eq(datum1.boost_type)
      expect(json['series']).to eq(datum1.series)
      expect(json['size']).to eq(datum1.size)
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/weapon_skill_data/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end
end
