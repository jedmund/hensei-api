# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PartyShares', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let(:party) { create(:party, user: user) }

  before do
    create(:crew_membership, crew: crew, user: user)
  end

  describe 'GET /api/v1/parties/:party_id/shares' do
    context 'as party owner' do
      it 'returns list of shares' do
        share = create(:party_share, party: party, shareable: crew, shared_by: user)

        get "/api/v1/parties/#{party.id}/shares", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['shares'].length).to eq(1)
        expect(json['shares'][0]['id']).to eq(share.id)
      end

      it 'returns empty array when no shares' do
        get "/api/v1/parties/#{party.id}/shares", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['shares']).to eq([])
      end
    end

    context 'as non-owner' do
      let(:other_user) { create(:user) }
      let(:other_token) do
        Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      end
      let(:other_headers) { { 'Authorization' => "Bearer #{other_token.token}" } }

      it 'returns unauthorized' do
        get "/api/v1/parties/#{party.id}/shares", headers: other_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get "/api/v1/parties/#{party.id}/shares"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/parties/:party_id/shares' do
    context 'as party owner in a crew' do
      it 'shares the party with their crew' do
        post "/api/v1/parties/#{party.id}/shares", headers: auth_headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['share']['shareable_type']).to eq('crew')
        expect(json['share']['shareable']['id']).to eq(crew.id)
      end

      it 'returns error when already shared' do
        create(:party_share, party: party, shareable: crew, shared_by: user)

        post "/api/v1/parties/#{party.id}/shares", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as party owner not in a crew' do
      before do
        user.active_crew_membership.retire!
      end

      it 'returns not_in_crew error' do
        post "/api/v1/parties/#{party.id}/shares", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('not_in_crew')
      end
    end

    context 'as non-owner' do
      let(:other_user) { create(:user) }
      let(:other_token) do
        Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      end
      let(:other_headers) { { 'Authorization' => "Bearer #{other_token.token}" } }

      it 'returns unauthorized' do
        post "/api/v1/parties/#{party.id}/shares", headers: other_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/parties/:party_id/shares/:id' do
    let!(:share) { create(:party_share, party: party, shareable: crew, shared_by: user) }

    context 'as party owner' do
      it 'removes the share' do
        delete "/api/v1/parties/#{party.id}/shares/#{share.id}", headers: auth_headers

        expect(response).to have_http_status(:no_content)
        expect(PartyShare.exists?(share.id)).to be false
      end
    end

    context 'as non-owner' do
      let(:other_user) { create(:user) }
      let(:other_token) do
        Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      end
      let(:other_headers) { { 'Authorization' => "Bearer #{other_token.token}" } }

      it 'returns unauthorized' do
        delete "/api/v1/parties/#{party.id}/shares/#{share.id}", headers: other_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
