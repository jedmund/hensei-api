# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponKeys', type: :request do
  describe 'GET /api/v1/weapon_keys' do
    let!(:weapon_key1) { create(:weapon_key, slot: 1, group: 1) }
    let!(:weapon_key2) { create(:weapon_key, slot: 2, group: 2) }

    it 'returns all weapon keys with correct fields' do
      get '/api/v1/weapon_keys'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      entry = json.find { |k| k['id'] == weapon_key1.id }
      expect(entry['name']['en']).to eq(weapon_key1.name_en)
      expect(entry['name']['ja']).to eq(weapon_key1.name_jp)
      expect(entry['granblue_id']).to eq(weapon_key1.granblue_id)
      expect(entry['slug']).to eq(weapon_key1.slug)
      expect(entry['slot']).to eq(weapon_key1.slot)
      expect(entry['group']).to eq(weapon_key1.group)
      expect(entry['order']).to eq(weapon_key1.order)
    end

    it 'filters by slot and returns only matching keys' do
      get '/api/v1/weapon_keys', params: { slot: 1 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |key|
        expect(key['slot']).to eq(1)
      end
      ids = json.map { |k| k['id'] }
      expect(ids).to include(weapon_key1.id)
      expect(ids).not_to include(weapon_key2.id)
    end

    it 'filters by group and returns only matching keys' do
      get '/api/v1/weapon_keys', params: { group: 2 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |key|
        expect(key['group']).to eq(2)
      end
      ids = json.map { |k| k['id'] }
      expect(ids).to include(weapon_key2.id)
      expect(ids).not_to include(weapon_key1.id)
    end

    it 'filters by series_slug' do
      opus_key = create(:weapon_key, :opus_key)

      get '/api/v1/weapon_keys', params: { series_slug: 'dark-opus' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      ids = json.map { |k| k['id'] }
      expect(ids).to include(opus_key.id)
    end
  end
end
