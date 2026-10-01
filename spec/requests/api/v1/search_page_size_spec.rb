# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search page size', type: :request do
  it 'caps results at 50 per page' do
    create_list(:character, 60 - Character.count) if Character.count < 60

    post '/api/v1/search/characters', params: { search: { locale: 'en' } }.to_json,
                                      headers: { 'Content-Type' => 'application/json', 'X-Per-Page' => '100' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['results'].length).to eq(50)
    expect(response.parsed_body['meta']['count']).to be > 50
  end
end
