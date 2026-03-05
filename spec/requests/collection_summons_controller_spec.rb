require 'rails_helper'

RSpec.describe 'Collection Summons API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:summon) { create(:summon) }

  describe 'GET /api/v1/collection/summons' do
    let(:summon1) { create(:summon) }
    let(:summon2) { create(:summon) }
    let!(:collection_summon1) { create(:collection_summon, user: user, summon: summon1, uncap_level: 5) }
    let!(:collection_summon2) { create(:collection_summon, user: user, summon: summon2, uncap_level: 3) }
    let!(:other_user_summon) { create(:collection_summon, user: other_user) }

    it 'returns the current user\'s collection summons' do
      get '/api/v1/collection/summons', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['collection_summons'].length).to eq(2)
      expect(json['meta']['count']).to eq(2)
    end

    it 'supports pagination' do
      get '/api/v1/collection/summons', params: { page: 1, limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['collection_summons'].length).to eq(1)
      expect(json['meta']['total_pages']).to be >= 2
    end

    it 'supports filtering by summon' do
      get '/api/v1/collection/summons', params: { summon_id: summon1.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      summons = json['collection_summons']
      expect(summons.length).to eq(1)
      expect(summons.first['summon']['id']).to eq(summon1.id)
    end

    it 'supports filtering by both element and rarity' do
      fire_ssr = create(:summon, element: 0, rarity: 4)
      water_ssr = create(:summon, element: 1, rarity: 4)
      fire_sr = create(:summon, element: 0, rarity: 3)

      create(:collection_summon, user: user, summon: fire_ssr)
      create(:collection_summon, user: user, summon: water_ssr)
      create(:collection_summon, user: user, summon: fire_sr)

      get '/api/v1/collection/summons', params: { element: 0, rarity: 4 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      summons = json['collection_summons']
      expect(summons.length).to eq(1)
      expect(summons.first['summon']['element']).to eq(0)
      expect(summons.first['summon']['rarity']).to eq(4)
    end

    it 'returns unauthorized without authentication' do
      get '/api/v1/collection/summons'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/collection/summons/:id' do
    let!(:collection_summon) { create(:collection_summon, user: user, summon: summon) }

    it 'returns the collection summon' do
      get "/api/v1/collection/summons/#{collection_summon.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(collection_summon.id)
      expect(json['summon']['id']).to eq(summon.id)
    end

    it 'returns not found for other user\'s summon' do
      other_collection = create(:collection_summon, user: other_user)
      get "/api/v1/collection/summons/#{other_collection.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for non-existent summon' do
      get "/api/v1/collection/summons/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/collection/summons' do
    let(:valid_attributes) do
      {
        collection_summon: {
          summon_id: summon.id,
          uncap_level: 3,
          transcendence_step: 0
        }
      }
    end

    it 'creates a new collection summon' do
      expect do
        post '/api/v1/collection/summons', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionSummon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['summon']['id']).to eq(summon.id)
      expect(json['uncap_level']).to eq(3)
    end

    it 'allows multiple copies of the same summon' do
      create(:collection_summon, user: user, summon: summon)

      expect do
        post '/api/v1/collection/summons', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionSummon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['summon']['id']).to eq(summon.id)
    end

    it 'returns error with invalid transcendence' do
      invalid_attributes = valid_attributes.deep_merge(
        collection_summon: { uncap_level: 3, transcendence_step: 5 }
      )

      post '/api/v1/collection/summons', params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('requires uncap level 5')
    end
  end

  describe 'PUT /api/v1/collection/summons/:id' do
    let!(:collection_summon) { create(:collection_summon, user: user, summon: summon, uncap_level: 3) }

    it 'updates the collection summon' do
      update_attributes = {
        collection_summon: {
          uncap_level: 5
        }
      }

      put "/api/v1/collection/summons/#{collection_summon.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['uncap_level']).to eq(5)
    end

    it 'returns not found for other user\'s summon' do
      other_collection = create(:collection_summon, user: other_user)
      update_attributes = { collection_summon: { uncap_level: 5 } }

      put "/api/v1/collection/summons/#{other_collection.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error with invalid transcendence' do
      invalid_attributes = {
        collection_summon: {
          uncap_level: 3,  # Keep it at 3
          transcendence_step: 5  # Invalid: requires uncap level 5
        }
      }

      put "/api/v1/collection/summons/#{collection_summon.id}",
          params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('requires uncap level 5')
    end
  end

  describe 'DELETE /api/v1/collection/summons/:id' do
    let!(:collection_summon) { create(:collection_summon, user: user, summon: summon) }

    it 'deletes the collection summon' do
      expect do
        delete "/api/v1/collection/summons/#{collection_summon.id}", headers: headers
      end.to change(CollectionSummon, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns not found for other user\'s summon' do
      other_collection = create(:collection_summon, user: other_user)

      expect do
        delete "/api/v1/collection/summons/#{other_collection.id}", headers: headers
      end.not_to change(CollectionSummon, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end