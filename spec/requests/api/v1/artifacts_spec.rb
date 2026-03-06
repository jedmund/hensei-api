# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Artifacts API', type: :request do
  describe 'GET /api/v1/artifacts' do
    let!(:standard_artifact) { create(:artifact, proficiency: :sabre) }
    let!(:quirk_artifact) { create(:artifact, :quirk) }

    it 'returns all artifacts' do
      get '/api/v1/artifacts'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifacts'].length).to eq(2)
    end

    it 'filters by rarity' do
      get '/api/v1/artifacts', params: { rarity: 'standard' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifacts'].length).to eq(1)
      expect(json['artifacts'].first['rarity']).to eq('standard')
    end

    it 'filters by proficiency' do
      create(:artifact, proficiency: :dagger)

      get '/api/v1/artifacts', params: { proficiency: 'sabre' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['artifacts'].all? { |a| a['proficiency'] == 'sabre' }).to be true
    end
  end

  describe 'GET /api/v1/artifacts/:id' do
    let!(:artifact) { create(:artifact) }

    it 'returns the artifact' do
      get "/api/v1/artifacts/#{artifact.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(artifact.id)
      expect(json['name']['en']).to eq(artifact.name_en)
    end

    it 'returns not found for non-existent artifact' do
      get "/api/v1/artifacts/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
