# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Guidebooks', type: :request do
  describe 'GET /api/v1/guidebooks' do
    let!(:guidebook1) { create(:guidebook) }
    let!(:guidebook2) { create(:guidebook) }

    it 'returns all guidebooks' do
      get '/api/v1/guidebooks'
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to be >= 2
    end
  end
end
