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

    # Regression: sorting by name in a Japanese locale must order by the real
    # name_jp column (was a 500: PG undefined column name_ja).
    it 'does not error when sorting by name in ja locale' do
      create(:character)
      post '/api/v1/search/characters',
           params: { search: { page: 1, locale: 'ja', sort: 'name', order: 'asc' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
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

    context 'when filtering by proficiency' do
      # Sabre = 1, Dagger = 2, Axe = 3
      let!(:sabre_primary) { create(:character, proficiency1: 1, proficiency2: nil) }
      let!(:sabre_secondary) { create(:character, proficiency1: 3, proficiency2: 1) }
      let!(:no_sabre) { create(:character, proficiency1: 2, proficiency2: 3) }

      it 'matches characters with the proficiency in either slot' do
        post '/api/v1/search/characters',
             params: { search: { filters: { proficiency1: [1] }, page: 1 } }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |r| r['id'] }
        expect(ids).to include(sabre_primary.id, sabre_secondary.id)
        expect(ids).not_to include(no_sabre.id)
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

    # Regression: clients send "jp" for Japanese, but the search scope is
    # ja_search. The locale must normalize so it doesn't call a missing
    # jp_search scope (was a 500: NameError undefined method 'jp_search').
    it 'does not error when given a jp locale with a query' do
      base = create(:job)
      job = create(:job, base_job: base)
      create(:job_skill, job: job)
      post '/api/v1/search/job_skills',
           params: { search: { job: job.id, locale: 'jp', query: 'skill' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    # Regression: a job with no base_job (e.g. a base job itself) made the query
    # dereference job.base_job.id on nil -> 500 NoMethodError. Both branches.
    it 'does not error for a job without a base_job (empty query)' do
      job = create(:job, base_job: nil)
      create(:job_skill, job: job)
      post '/api/v1/search/job_skills',
           params: { search: { job: job.id, locale: 'en', query: '' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'does not error for a job without a base_job (with query)' do
      job = create(:job, base_job: nil)
      create(:job_skill, job: job)
      post '/api/v1/search/job_skills',
           params: { search: { job: job.id, locale: 'en', query: 'skill' } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
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
