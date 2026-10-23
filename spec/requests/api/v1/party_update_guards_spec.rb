# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Party update guards', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'PUT /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user, name: 'Old Name') }

    it 'ignores collection_source_user_id' do
      other_user = create(:user)

      put "/api/v1/parties/#{party.id}",
          params: { party: { name: 'New Name', collection_source_user_id: other_user.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      party.reload
      expect(party.name).to eq('New Name')
      expect(party.collection_source_user_id).to be_nil
    end

    it 'keeps an existing collection source' do
      party.update!(collection_source_user_id: user.id)

      put "/api/v1/parties/#{party.id}",
          params: { party: { collection_source_user_id: create(:user).id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(party.reload.collection_source_user_id).to eq(user.id)
    end

    it 'returns 404 for an id that is not a UUID' do
      put '/api/v1/parties/not-a-uuid', params: { party: { name: 'x' } }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for a well-formed UUID that does not exist' do
      put "/api/v1/parties/#{SecureRandom.uuid}", params: { party: { name: 'x' } }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/parties/:id/grid_update' do
    it 'returns 404 for an id that is not a UUID' do
      post '/api/v1/parties/not-a-uuid/grid_update', params: { operations: [] }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/parties/:id' do
    it 'returns 404 for an id that is not a UUID' do
      delete '/api/v1/parties/not-a-uuid', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
