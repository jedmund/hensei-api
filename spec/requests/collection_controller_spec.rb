require 'rails_helper'

RSpec.describe 'Collection Viewing API', type: :request do
  let(:user) { create(:user, collection_privacy: 'everyone') }
  let(:private_user) { create(:user, collection_privacy: 'private_collection') }
  let(:crew_only_user) { create(:user, collection_privacy: 'crew_only') }
  let(:viewer) { create(:user) }

  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: viewer.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  # Create some collection items for testing
  before do
    # User's collection
    create(:collection_character, user: user)
    create(:collection_weapon, user: user)
    create(:collection_summon, user: user)
    create(:collection_job_accessory, user: user)

    # Private user's collection
    create(:collection_character, user: private_user)
    create(:collection_weapon, user: private_user)
  end

  describe 'GET /api/v1/users/:user_id/collection' do
    context 'viewing public collection' do
      it 'returns the complete collection' do
        get "/api/v1/users/#{user.id}/collection", headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('characters')
        expect(json).to have_key('weapons')
        expect(json).to have_key('summons')
        expect(json).to have_key('job_accessories')
        expect(json['characters'].length).to eq(1)
        expect(json['weapons'].length).to eq(1)
        expect(json['summons'].length).to eq(1)
        expect(json['job_accessories'].length).to eq(1)
      end

      it 'returns only characters when type=characters' do
        get "/api/v1/users/#{user.id}/collection", params: { type: 'characters' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('characters')
        expect(json).not_to have_key('weapons')
        expect(json).not_to have_key('summons')
        expect(json['characters'].length).to eq(1)
      end

      it 'returns only weapons when type=weapons' do
        get "/api/v1/users/#{user.id}/collection", params: { type: 'weapons' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('weapons')
        expect(json).not_to have_key('characters')
        expect(json).not_to have_key('summons')
        expect(json['weapons'].length).to eq(1)
      end

      it 'returns only summons when type=summons' do
        get "/api/v1/users/#{user.id}/collection", params: { type: 'summons' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('summons')
        expect(json).not_to have_key('characters')
        expect(json).not_to have_key('weapons')
        expect(json['summons'].length).to eq(1)
      end

      it 'returns only job accessories when type=job_accessories' do
        get "/api/v1/users/#{user.id}/collection", params: { type: 'job_accessories' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('job_accessories')
        expect(json).not_to have_key('characters')
        expect(json).not_to have_key('weapons')
        expect(json['job_accessories'].length).to eq(1)
      end

      it 'works without authentication for public collections' do
        get "/api/v1/users/#{user.id}/collection"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('characters')
      end
    end

    context 'viewing private collection' do
      it 'returns forbidden for non-owner' do
        get "/api/v1/users/#{private_user.id}/collection", headers: headers

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json['error']).to include('do not have permission')
      end

      it 'allows owner to view their own private collection' do
        owner_token = Doorkeeper::AccessToken.create!(
          resource_owner_id: private_user.id,
          expires_in: 30.days,
          scopes: 'public'
        )
        owner_headers = {
          'Authorization' => "Bearer #{owner_token.token}",
          'Content-Type' => 'application/json'
        }

        get "/api/v1/users/#{private_user.id}/collection", headers: owner_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('characters')
        expect(json).to have_key('weapons')
      end
    end

    context 'viewing crew-only collection' do
      it 'returns forbidden for non-crew members' do
        get "/api/v1/users/#{crew_only_user.id}/collection", headers: headers

        expect(response).to have_http_status(:forbidden)
        json = response.parsed_body
        expect(json['error']).to include('do not have permission')
      end

      it 'allows owner to view their own crew-only collection' do
        owner_token = Doorkeeper::AccessToken.create!(
          resource_owner_id: crew_only_user.id,
          expires_in: 30.days,
          scopes: 'public'
        )
        owner_headers = {
          'Authorization' => "Bearer #{owner_token.token}",
          'Content-Type' => 'application/json'
        }

        get "/api/v1/users/#{crew_only_user.id}/collection", headers: owner_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('characters')
      end
    end

    context 'error handling' do
      it 'returns not found for non-existent user' do
        get "/api/v1/users/#{SecureRandom.uuid}/collection", headers: headers

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json['error']).to include('User not found')
      end
    end
  end
end