# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Favorites', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/favorites' do
    it 'creates a favorite and returns it' do
      party = create(:party, user: other_user)
      expect {
        post '/api/v1/favorites',
             params: { favorite: { party_id: party.id } }.to_json,
             headers: auth_headers
      }.to change(Favorite, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body['favorite']
      expect(json['user']['id']).to eq(user.id)
      expect(json['party']['id']).to eq(party.id)
    end

    it 'returns error when favoriting own party' do
      party = create(:party, user: user)
      post '/api/v1/favorites',
           params: { favorite: { party_id: party.id } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns error when favorite already exists' do
      party = create(:party, user: other_user)
      create(:favorite, user: user, party: party)
      post '/api/v1/favorites',
           params: { favorite: { party_id: party.id } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 without authentication' do
      party = create(:party, user: other_user)
      post '/api/v1/favorites',
           params: { favorite: { party_id: party.id } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/favorites' do
    it 'deletes a favorite' do
      party = create(:party, user: other_user)
      create(:favorite, user: user, party: party)
      expect {
        delete '/api/v1/favorites',
               params: { favorite: { party_id: party.id } }.to_json,
               headers: auth_headers
      }.to change(Favorite, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for non-existent favorite' do
      party = create(:party, user: other_user)
      delete '/api/v1/favorites',
             params: { favorite: { party_id: party.id } }.to_json,
             headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
