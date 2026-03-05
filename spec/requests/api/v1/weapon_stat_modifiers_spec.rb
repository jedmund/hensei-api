# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::WeaponStatModifiers', type: :request do
  let!(:ax_mod) { create(:weapon_stat_modifier, :ax_atk) }
  let!(:befoul_mod) { create(:weapon_stat_modifier, :befoul_def_down) }

  describe 'GET /api/v1/weapon_stat_modifiers' do
    it 'returns all stat modifiers with correct fields' do
      get '/api/v1/weapon_stat_modifiers'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_stat_modifiers']
      expect(json.length).to be >= 2

      entry = json.find { |m| m['id'] == ax_mod.id }
      expect(entry['slug']).to eq('ax_atk')
      expect(entry['name_en']).to eq('ATK')
      expect(entry['category']).to eq('ax')
      expect(entry['stat']).to eq('atk')
      expect(entry['polarity']).to eq(1)
      expect(entry['suffix']).to eq('%')
    end

    it 'filters by category and excludes non-matching' do
      get '/api/v1/weapon_stat_modifiers', params: { category: 'ax' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['weapon_stat_modifiers']
      json.each do |m|
        expect(m['category']).to eq('ax')
      end
      ids = json.map { |m| m['id'] }
      expect(ids).to include(ax_mod.id)
      expect(ids).not_to include(befoul_mod.id)
    end
  end

  describe 'GET /api/v1/weapon_stat_modifiers/:id' do
    it 'returns the correct stat modifier' do
      get "/api/v1/weapon_stat_modifiers/#{befoul_mod.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(befoul_mod.id)
      expect(json['slug']).to eq('befoul_def_down')
      expect(json['category']).to eq('befoulment')
      expect(json['polarity']).to eq(-1)
    end
  end
end
