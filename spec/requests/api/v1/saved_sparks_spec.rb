# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::SavedSparks', type: :request do
  let(:owner) { create(:user) }
  let(:stranger) { create(:user) }
  let(:headers) { bearer_headers(owner).merge('Content-Type' => 'application/json') }
  let(:json) { { 'Content-Type' => 'application/json' } }

  let(:valid_body) do
    {
      spark: {
        spark_date: (Date.current - 3).iso8601,
        draws: 280,
        pool: 'flash',
        season: 'halloween',
        characters: %w[1040000000 1040000100],
        moons: %w[1040000200],
        summons: %w[2040000000],
        sparked: { column: 'characters', index: 1 }
      }
    }
  end

  describe 'GET /api/v1/sparks' do
    it 'returns 401 when signed out' do
      get '/api/v1/sparks'
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists only the current user's sparks, newest spark date first" do
      older = create(:saved_spark, user: owner, spark_date: Date.current - 30)
      newest = create(:saved_spark, user: owner, spark_date: Date.current)
      middle = create(:saved_spark, user: owner, spark_date: Date.current - 10)
      create(:saved_spark, user: stranger)

      get '/api/v1/sparks', headers: headers

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['results'].pluck('id')).to eq([newest.id, middle.id, older.id])
      expect(body['meta']).to eq('count' => 3, 'total_pages' => 1, 'per_page' => 15)
    end

    it 'puts the later-saved spark first on the same date' do
      first = create(:saved_spark, user: owner, created_at: 2.hours.ago)
      second = create(:saved_spark, user: owner, created_at: 1.hour.ago)

      get '/api/v1/sparks', headers: headers

      expect(response.parsed_body['results'].pluck('id')).to eq([second.id, first.id])
    end

    it 'paginates with X-Per-Page and page' do
      sparks = Array.new(3) { |i| create(:saved_spark, user: owner, spark_date: Date.current - i) }

      get '/api/v1/sparks', params: { page: 2 }, headers: headers.merge('X-Per-Page' => '2')

      body = response.parsed_body
      expect(body['results'].pluck('id')).to eq([sparks.last.id])
      expect(body['meta']).to eq('count' => 3, 'total_pages' => 2, 'per_page' => 2)
    end
  end

  describe 'GET /api/v1/sparks/:id' do
    let(:spark) do
      create(:saved_spark, user: owner, spark_date: Date.new(2026, 11, 1), draws: 250,
                           sparked_column: 'summons', sparked_index: 0)
    end

    it 'returns the spark in the shape the spark maker uses' do
      get "/api/v1/sparks/#{spark.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['spark']).to include(
        'id' => spark.id,
        'spark_date' => '2026-11-01',
        'draws' => 250,
        'pool' => nil,
        'season' => nil,
        'characters' => %w[1040000000 1040000100],
        'moons' => %w[1040000200],
        'summons' => %w[2040000000],
        'sparked' => { 'column' => 'summons', 'index' => 0 }
      )
      expect(response.parsed_body['spark']).not_to have_key('user_id')
    end

    it 'returns 401 when signed out' do
      get "/api/v1/sparks/#{spark.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for someone else's spark" do
      get "/api/v1/sparks/#{spark.id}", headers: bearer_headers(stranger)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for an id that is not a uuid' do
      get '/api/v1/sparks/nope', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/sparks' do
    it 'returns 401 when signed out' do
      expect do
        post '/api/v1/sparks', params: valid_body.to_json, headers: json
      end.not_to change(SavedSpark, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'saves the spark to the current user' do
      post '/api/v1/sparks', params: valid_body.to_json, headers: headers

      expect(response).to have_http_status(:created)
      spark = SavedSpark.sole
      expect(spark).to have_attributes(user_id: owner.id, draws: 280, pool: 'flash', season: 'halloween',
                                       sparked_column: 'characters', sparked_index: 1,
                                       characters: %w[1040000000 1040000100])
      expect(response.parsed_body['spark']).to include('id' => spark.id,
                                                       'sparked' => { 'column' => 'characters', 'index' => 1 })
    end

    it 'ignores a user_id in the params' do
      body = valid_body.deep_merge(spark: { user_id: stranger.id })
      post '/api/v1/sparks', params: body.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(SavedSpark.sole.user_id).to eq(owner.id)
    end

    it 'saves an empty spark with no mark' do
      body = { spark: { spark_date: Date.current.iso8601, draws: 300,
                        characters: [], moons: [], summons: [], sparked: nil } }
      post '/api/v1/sparks', params: body.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['spark']).to include('characters' => [], 'sparked' => nil)
    end

    it 'rejects an invalid spark with its errors' do
      body = valid_body.deep_merge(spark: { spark_date: (Date.current + 5).iso8601, draws: 0,
                                            summons: %w[1040000000],
                                            sparked: { column: 'moons', index: 4 } })
      expect do
        post '/api/v1/sparks', params: body.to_json, headers: headers
      end.not_to change(SavedSpark, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors'].keys).to include('spark_date', 'draws', 'summons', 'sparked')
    end

    it 'requires a spark date' do
      body = valid_body.deep_merge(spark: { spark_date: nil })
      post '/api/v1/sparks', params: body.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to have_key('spark_date')
    end

    it 'rejects a mark that is not an object' do
      body = valid_body.deep_merge(spark: { sparked: 'c1' })
      post '/api/v1/sparks', params: body.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to have_key('sparked')
    end

    it 'rejects a body without a spark' do
      post '/api/v1/sparks', params: { draws: 1 }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /api/v1/sparks/:id' do
    let!(:spark) { create(:saved_spark, user: owner, sparked_column: 'characters', sparked_index: 0) }

    it 'returns 401 when signed out' do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { draws: 10 } }.to_json, headers: json
      expect(response).to have_http_status(:unauthorized)
      expect(spark.reload.draws).to eq(300)
    end

    it "returns 404 for someone else's spark and leaves it alone" do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { draws: 10 } }.to_json,
                                          headers: bearer_headers(stranger).merge(json)
      expect(response).to have_http_status(:not_found)
      expect(spark.reload.draws).to eq(300)
    end

    it 'updates the given fields' do
      patch "/api/v1/sparks/#{spark.id}", params: valid_body.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(spark.reload).to have_attributes(draws: 280, spark_date: Date.current - 3,
                                              sparked_column: 'characters', sparked_index: 1)
    end

    it 'clears the mark with null and empties a list' do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { sparked: nil, characters: [] } }.to_json,
                                          headers: headers

      expect(response).to have_http_status(:ok)
      expect(spark.reload).to have_attributes(sparked_column: nil, sparked_index: nil, characters: [],
                                              moons: %w[1040000200])
    end

    it 'leaves the mark alone when it is not sent' do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { draws: 123 } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(spark.reload).to have_attributes(draws: 123, sparked_column: 'characters', sparked_index: 0)
    end

    it 'cannot move the spark to another user' do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { user_id: stranger.id, draws: 5 } }.to_json,
                                          headers: headers

      expect(response).to have_http_status(:ok)
      expect(spark.reload.user_id).to eq(owner.id)
    end

    it 'rejects an edit that leaves the mark pointing past its column' do
      patch "/api/v1/sparks/#{spark.id}", params: { spark: { characters: [] } }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to have_key('sparked')
      expect(spark.reload.characters).to eq(%w[1040000000 1040000100])
    end
  end

  describe 'DELETE /api/v1/sparks/:id' do
    let!(:spark) { create(:saved_spark, user: owner) }

    it 'returns 401 when signed out' do
      delete "/api/v1/sparks/#{spark.id}"
      expect(response).to have_http_status(:unauthorized)
      expect(SavedSpark.exists?(spark.id)).to be(true)
    end

    it "returns 404 for someone else's spark and keeps it" do
      delete "/api/v1/sparks/#{spark.id}", headers: bearer_headers(stranger)
      expect(response).to have_http_status(:not_found)
      expect(SavedSpark.exists?(spark.id)).to be(true)
    end

    it 'deletes the spark' do
      delete "/api/v1/sparks/#{spark.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(SavedSpark.exists?(spark.id)).to be(false)
    end
  end
end
