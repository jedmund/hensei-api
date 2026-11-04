# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Guidebooks', type: :request do
  describe 'GET /api/v1/guidebooks' do
    let!(:first_guidebook) { create(:guidebook) }
    let!(:second_guidebook) { create(:guidebook) }

    it 'returns all guidebooks with correct fields' do
      get '/api/v1/guidebooks'
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to be >= 2

      ids = json.map { |g| g['id'] }
      expect(ids).to include(first_guidebook.id, second_guidebook.id)

      entry = json.find { |g| g['id'] == first_guidebook.id }
      expect(entry['granblue_id']).to eq(first_guidebook.granblue_id)
      expect(entry['name']['en']).to eq(first_guidebook.name_en)
      expect(entry['name']['ja']).to eq(first_guidebook.name_jp)
      expect(entry['description']['en']).to eq(first_guidebook.description_en)
      expect(entry['description']['ja']).to eq(first_guidebook.description_jp)
    end
  end
end
