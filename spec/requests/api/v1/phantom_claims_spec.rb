# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PhantomClaims', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  describe 'GET /api/v1/pending_phantom_claims' do
    it 'returns pending phantom claims with player, crew, and claimed_by fields' do
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      phantom = create(:phantom_player, crew: crew, claimed_by: user, claim_confirmed: false)

      get '/api/v1/pending_phantom_claims', headers: auth_headers
      expect(response).to have_http_status(:ok)

      json = response.parsed_body['phantom_claims']
      expect(json.length).to eq(1)

      claim = json.first
      expect(claim['id']).to eq(phantom.id)
      expect(claim['name']).to eq(phantom.name)
      expect(claim['claim_confirmed']).to eq(false)
      expect(claim['claimed']).to eq(true)
      expect(claim['crew']).to be_present
      expect(claim['crew']['id']).to eq(crew.id)
      expect(claim['claimed_by']).to be_present
      expect(claim['claimed_by']['id']).to eq(user.id)
    end

    it 'excludes confirmed claims' do
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      create(:phantom_player, crew: crew, claimed_by: user, claim_confirmed: true)

      get '/api/v1/pending_phantom_claims', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['phantom_claims'].length).to eq(0)
    end

    it 'excludes claims belonging to other users' do
      other_user = create(:user)
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      create(:crew_membership, crew: crew, user: other_user)
      create(:phantom_player, crew: crew, claimed_by: other_user, claim_confirmed: false)

      get '/api/v1/pending_phantom_claims', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['phantom_claims'].length).to eq(0)
    end

    it 'returns 401 without authentication' do
      get '/api/v1/pending_phantom_claims'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
