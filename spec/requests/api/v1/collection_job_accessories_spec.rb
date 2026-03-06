require 'rails_helper'

RSpec.describe 'Collection Job Accessories API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:job) { create(:job) }
  let(:job_accessory) { create(:job_accessory, job: job) }

  describe 'GET /api/v1/collection/job_accessories' do
    let(:job1) { create(:job) }
    let(:job2) { create(:job) }
    let(:job_accessory1) { create(:job_accessory, job: job1) }
    let(:job_accessory2) { create(:job_accessory, job: job2) }
    let!(:collection_accessory1) { create(:collection_job_accessory, user: user, job_accessory: job_accessory1) }
    let!(:collection_accessory2) { create(:collection_job_accessory, user: user, job_accessory: job_accessory2) }
    let!(:other_user_accessory) { create(:collection_job_accessory, user: other_user) }

    it 'returns the current user\'s collection job accessories' do
      get '/api/v1/collection/job_accessories', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['collection_job_accessories'].length).to eq(2)
    end

    it 'supports filtering by job' do
      get '/api/v1/collection/job_accessories', params: { job_id: job1.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      accessories = json['collection_job_accessories']
      expect(accessories.length).to eq(1)
      expect(accessories.first['job_accessory']['job']['id']).to eq(job1.id)
    end

    it 'returns unauthorized without authentication' do
      get '/api/v1/collection/job_accessories'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/collection/job_accessories/:id' do
    let!(:collection_accessory) { create(:collection_job_accessory, user: user, job_accessory: job_accessory) }

    it 'returns the collection job accessory' do
      get "/api/v1/collection/job_accessories/#{collection_accessory.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(collection_accessory.id)
      expect(json['job_accessory']['id']).to eq(job_accessory.id)
    end

    it 'returns not found for other user\'s job accessory' do
      other_collection = create(:collection_job_accessory, user: other_user)
      get "/api/v1/collection/job_accessories/#{other_collection.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for non-existent job accessory' do
      get "/api/v1/collection/job_accessories/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns unauthorized without authentication' do
      get "/api/v1/collection/job_accessories/#{collection_accessory.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/collection/job_accessories' do
    let(:valid_attributes) do
      {
        collection_job_accessory: {
          job_accessory_id: job_accessory.id
        }
      }
    end

    it 'creates a new collection job accessory' do
      expect do
        post '/api/v1/collection/job_accessories', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionJobAccessory, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['job_accessory']['id']).to eq(job_accessory.id)
    end

    it 'returns error when job accessory already in collection' do
      create(:collection_job_accessory, user: user, job_accessory: job_accessory)

      post '/api/v1/collection/job_accessories', params: valid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:conflict)
      json = response.parsed_body
      expect(json['error']['message']).to include('already exists in your collection')
    end

    it 'returns error for non-existent job accessory' do
      invalid_attributes = {
        collection_job_accessory: {
          job_accessory_id: SecureRandom.uuid
        }
      }

      expect {
        post '/api/v1/collection/job_accessories', params: invalid_attributes.to_json, headers: headers
      }.not_to change(CollectionJobAccessory, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/collection/job_accessories/:id' do
    let!(:collection_accessory) { create(:collection_job_accessory, user: user, job_accessory: job_accessory) }

    it 'deletes the collection job accessory' do
      expect do
        delete "/api/v1/collection/job_accessories/#{collection_accessory.id}", headers: headers
      end.to change(CollectionJobAccessory, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns not found for other user\'s job accessory' do
      other_collection = create(:collection_job_accessory, user: other_user)

      expect do
        delete "/api/v1/collection/job_accessories/#{other_collection.id}", headers: headers
      end.not_to change(CollectionJobAccessory, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for non-existent job accessory' do
      delete "/api/v1/collection/job_accessories/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end