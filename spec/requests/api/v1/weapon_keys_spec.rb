# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponKeys', type: :request do
  describe 'GET /api/v1/weapon_keys' do
    let!(:weapon_key1) { create(:weapon_key) }
    let!(:weapon_key2) { create(:weapon_key) }

    it 'returns all weapon keys' do
      get '/api/v1/weapon_keys'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 2
    end

    it 'filters by slot' do
      get '/api/v1/weapon_keys', params: { slot: weapon_key1.slot }
      expect(response).to have_http_status(:ok)
      response.parsed_body.each do |key|
        expect(key['slot']).to eq(weapon_key1.slot)
      end
    end

    it 'filters by group' do
      get '/api/v1/weapon_keys', params: { group: weapon_key1.group }
      expect(response).to have_http_status(:ok)
      response.parsed_body.each do |key|
        expect(key['group']).to eq(weapon_key1.group)
      end
    end

    it 'filters by series_slug' do
      series = weapon_key1.weapon_series.first
      if series
        get '/api/v1/weapon_keys', params: { series_slug: series.slug }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
