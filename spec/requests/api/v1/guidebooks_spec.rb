# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Guidebooks', type: :request do
  describe 'GET /api/v1/guidebooks' do
    let!(:guidebook1) { create(:guidebook) }
    let!(:guidebook2) { create(:guidebook) }

    it 'returns all guidebooks with correct fields' do
      get '/api/v1/guidebooks'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      ids = json.map { |g| g['id'] }
      expect(ids).to include(guidebook1.id, guidebook2.id)

      entry = json.find { |g| g['id'] == guidebook1.id }
      expect(entry['granblue_id']).to eq(guidebook1.granblue_id)
      expect(entry['name']['en']).to eq(guidebook1.name_en)
      expect(entry['name']['ja']).to eq(guidebook1.name_jp)
      expect(entry['description']['en']).to eq(guidebook1.description_en)
      expect(entry['description']['ja']).to eq(guidebook1.description_jp)
    end
  end
end
