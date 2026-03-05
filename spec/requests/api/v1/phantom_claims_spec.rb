# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PhantomClaims', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  describe 'GET /api/v1/pending_phantom_claims' do
    it 'returns pending phantom claims for current user' do
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      phantom = create(:phantom_player, crew: crew, claimed_by: user, claim_confirmed: false)

      get '/api/v1/pending_phantom_claims', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['phantom_claims'].length).to eq(1)
    end

    it 'excludes confirmed claims' do
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      create(:phantom_player, crew: crew, claimed_by: user, claim_confirmed: true)

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
