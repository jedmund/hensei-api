# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponKeys', type: :request do
  describe 'GET /api/v1/weapon_keys' do
    let!(:first_weapon_key) { create(:weapon_key, slot: 1, group: 1) }
    let!(:second_weapon_key) { create(:weapon_key, slot: 2, group: 2) }

    it 'returns all weapon keys with correct fields' do
      get '/api/v1/weapon_keys'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      entry = json.find { |k| k['id'] == first_weapon_key.id }
      expect(entry['name']['en']).to eq(first_weapon_key.name_en)
      expect(entry['name']['ja']).to eq(first_weapon_key.name_jp)
      expect(entry['granblue_id']).to eq(first_weapon_key.granblue_id)
      expect(entry['slug']).to eq(first_weapon_key.slug)
      expect(entry['slot']).to eq(first_weapon_key.slot)
      expect(entry['group']).to eq(first_weapon_key.group)
      expect(entry['order']).to eq(first_weapon_key.order)
    end

    it 'filters by slot and returns only matching keys' do
      get '/api/v1/weapon_keys', params: { slot: 1 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |key|
        expect(key['slot']).to eq(1)
      end
      ids = json.pluck('id')
      expect(ids).to include(first_weapon_key.id)
      expect(ids).not_to include(second_weapon_key.id)
    end

    it 'filters by group and returns only matching keys' do
      get '/api/v1/weapon_keys', params: { group: 2 }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      json.each do |key|
        expect(key['group']).to eq(2)
      end
      ids = json.pluck('id')
      expect(ids).to include(second_weapon_key.id)
      expect(ids).not_to include(first_weapon_key.id)
    end

    it 'filters by series_slug' do
      opus_key = create(:weapon_key, :opus_key)

      get '/api/v1/weapon_keys', params: { series_slug: 'dark-opus' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      ids = json.pluck('id')
      expect(ids).to include(opus_key.id)
    end

    it 'filters by series_slug only, ignoring the legacy series and leaving out other series' do
      opus_key = create(:weapon_key, :opus_key)
      draconic_key = create(:weapon_key, :draconic_key)

      get '/api/v1/weapon_keys', params: { series_slug: 'draconic', series: 3 }

      ids = response.parsed_body.pluck('id')
      expect(ids).to eq([draconic_key.id])
      expect(ids).not_to include(opus_key.id)
    end

    it 'ignores an unknown series_slug' do
      get '/api/v1/weapon_keys', params: { series_slug: 'nope' }

      expect(response.parsed_body.pluck('id')).to match_array(WeaponKey.pluck(:id))
    end

    it 'filters by the legacy integer series' do
      draconic_only = create(:weapon_key, series: [27])

      get '/api/v1/weapon_keys', params: { series: '27' }
      ids = response.parsed_body.pluck('id')
      expect(ids).to include(first_weapon_key.id, second_weapon_key.id, draconic_only.id)
      expect(ids).to match_array(WeaponKey.where('27 = ANY(series)').pluck(:id))

      get '/api/v1/weapon_keys', params: { series: '3', slot: 2, group: 2 }
      expect(response.parsed_body.pluck('id')).to match_array(WeaponKey.where('3 = ANY(series)').where(slot: 2, group: 2).pluck(:id))
      expect(response.parsed_body.pluck('id')).to include(second_weapon_key.id)
      expect(response.parsed_body.pluck('id')).not_to include(draconic_only.id, first_weapon_key.id)
    end
  end
end
