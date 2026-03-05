# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Search', type: :request do
  describe 'GET /api/v1/search/suggestions' do
    it 'returns random suggestions' do
      get '/api/v1/search/suggestions', params: { count: 6 }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['suggestions']).to be_an(Array)
      expect(body['suggestions'].length).to be <= 6
    end

    it 'clamps count to valid range' do
      get '/api/v1/search/suggestions', params: { count: 100 }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['suggestions'].length).to be <= 30
    end
  end

  describe 'POST /api/v1/search/characters' do
    it 'returns characters without query' do
      post '/api/v1/search/characters',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'filters by element and returns only matching results' do
      post '/api/v1/search/characters',
           params: { search: { filters: { element: [1] }, page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)

      results = response.parsed_body['results']
      results.each do |r|
        expect(r['element']).to eq(1)
      end
    end
  end

  describe 'POST /api/v1/search/weapons' do
    it 'returns weapons without query' do
      post '/api/v1/search/weapons',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end
  end

  describe 'POST /api/v1/search/summons' do
    it 'returns summons without query' do
      post '/api/v1/search/summons',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end
  end

  describe 'POST /api/v1/search/jobs' do
    it 'returns jobs without query' do
      create(:job)
      post '/api/v1/search/jobs',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end
  end

  describe 'POST /api/v1/search/job_skills' do
    it 'returns error without job param' do
      post '/api/v1/search/job_skills',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/search/guidebooks' do
    it 'returns guidebooks with results and meta' do
      post '/api/v1/search/guidebooks',
           params: { search: { page: 1 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['results']).to be_an(Array)
      expect(json['meta']).to be_present
    end
  end
end
