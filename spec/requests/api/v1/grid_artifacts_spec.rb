# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::GridArtifacts', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user, edit_key: 'secret') }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:grid_character) { create(:grid_character, party: party) }
  let(:artifact) { create(:artifact) }

  describe 'POST /api/v1/grid_artifacts' do
    it 'creates a grid artifact' do
      post '/api/v1/grid_artifacts', params: {
        party_id: party.id,
        grid_artifact: {
          grid_character_id: grid_character.id,
          artifact_id: artifact.id,
          element: 'light',
          level: 1
        }
      }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'replaces existing artifact on same grid character' do
      create(:grid_artifact, grid_character: grid_character, artifact: artifact)
      new_artifact = create(:artifact)
      post '/api/v1/grid_artifacts', params: {
        party_id: party.id,
        grid_artifact: {
          grid_character_id: grid_character.id,
          artifact_id: new_artifact.id,
          element: 'light',
          level: 1
        }
      }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'rejects creation by non-owner' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      post '/api/v1/grid_artifacts', params: {
        party_id: party.id,
        grid_artifact: {
          grid_character_id: grid_character.id,
          artifact_id: artifact.id,
          element: 'light',
          level: 1
        }
      }.to_json, headers: { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/grid_artifacts/:id' do
    let!(:grid_artifact) { create(:grid_artifact, grid_character: grid_character, artifact: artifact) }

    it 'updates a grid artifact' do
      put "/api/v1/grid_artifacts/#{grid_artifact.id}",
          params: { grid_artifact: { level: 5 } }.to_json,
          headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects update by non-owner' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      put "/api/v1/grid_artifacts/#{grid_artifact.id}",
          params: { grid_artifact: { level: 5 } }.to_json,
          headers: { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/grid_artifacts/:id' do
    it 'deletes a grid artifact' do
      ga = create(:grid_artifact, grid_character: grid_character, artifact: artifact)
      delete "/api/v1/grid_artifacts/#{ga.id}", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for non-existent artifact' do
      delete '/api/v1/grid_artifacts/00000000-0000-0000-0000-000000000000', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/grid_artifacts/:id/sync' do
    let!(:grid_artifact) { create(:grid_artifact, grid_character: grid_character, artifact: artifact) }

    it 'returns error when no collection artifact linked' do
      post "/api/v1/grid_artifacts/#{grid_artifact.id}/sync", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
