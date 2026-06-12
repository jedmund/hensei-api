# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Statuses', type: :request do
  describe 'GET /api/v1/statuses' do
    it 'returns statuses under a root key' do
      status = Status.create!(
        name_en: 'Paralyzed',
        name_jp: '麻痺',
        family: 'Paralyzed',
        category: 'debuff',
        icon: 'status_101.png'
      )

      get '/api/v1/statuses'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['statuses'].length).to eq(1)
      expect(json['statuses'].first).to include(
        'id' => status.id,
        'name' => { 'en' => 'Paralyzed', 'ja' => '麻痺' },
        'family' => 'Paralyzed',
        'category' => 'debuff',
        'icon' => 'status_101.png'
      )
    end

    it 'filters by category' do
      buff = Status.create!(name_en: 'Double Strike', category: 'buff')
      Status.create!(name_en: 'Paralyzed', family: 'Paralyzed', category: 'debuff')

      get '/api/v1/statuses', params: { category: 'buff' }

      expect(response).to have_http_status(:ok)
      statuses = response.parsed_body['statuses']
      expect(statuses.pluck('id')).to eq([buff.id])
      expect(statuses.pluck('category')).to eq(['buff'])
    end

    it 'filters by family' do
      paralyzed = Status.create!(name_en: 'Paralyzed', family: 'Paralyzed', category: 'debuff')
      second_paralyzed = Status.create!(name_en: 'Paralyzed 2', family: 'Paralyzed', level: 2, category: 'debuff')
      Status.create!(name_en: 'Blinded', family: 'Blinded', category: 'debuff')

      get '/api/v1/statuses', params: { family: 'Paralyzed' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['statuses'].pluck('id')).to match_array([paralyzed.id, second_paralyzed.id])
    end
  end

  describe 'GET /api/v1/statuses/:id' do
    it 'returns a status by id' do
      status = Status.create!(
        game_ailment_id: '1558014001',
        name_en: 'Causal Intervention',
        name_jp: '因果干渉',
        family: 'Causal Intervention',
        level: 4,
        category: 'buff',
        icon: 'causal_intervention.png'
      )

      get "/api/v1/statuses/#{status.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'id' => status.id,
        'name' => { 'en' => 'Causal Intervention', 'ja' => '因果干渉' },
        'family' => 'Causal Intervention',
        'level' => 4,
        'category' => 'buff',
        'icon' => 'causal_intervention.png'
      )
    end
  end
end
