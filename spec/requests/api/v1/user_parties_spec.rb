# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::UserParties', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:raid) { create(:raid) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:unauth_headers) { { 'Content-Type' => 'application/json' } }

  describe 'GET /api/v1/users/:user_id/parties' do
    let!(:public_party) { create(:party, user: user, visibility: 1, raid: raid, element: 1) }
    let!(:unlisted_party) { create(:party, user: user, visibility: 2, raid: raid, element: 2) }
    let!(:private_party) { create(:party, user: user, visibility: 3, raid: raid, element: 1) }

    context 'as the owner' do
      it 'returns all parties including private' do
        get "/api/v1/users/#{user.username}/parties", headers: auth_headers
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(ids).to include(public_party.id, unlisted_party.id, private_party.id)
      end
    end

    context 'as another user' do
      let(:other_token) do
        Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      end
      let(:other_headers) do
        { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }
      end

      it 'returns only public parties' do
        get "/api/v1/users/#{user.username}/parties", headers: other_headers
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(ids).to include(public_party.id)
        expect(ids).not_to include(private_party.id)
      end
    end

    context 'without authentication' do
      it 'returns only public parties' do
        get "/api/v1/users/#{user.username}/parties", headers: unauth_headers
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(ids).to include(public_party.id)
        expect(ids).not_to include(private_party.id)
      end
    end

    context 'with element filter' do
      it 'filters parties by element' do
        get "/api/v1/users/#{user.username}/parties", params: { element: 1 }, headers: auth_headers
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(ids).to include(public_party.id, private_party.id)
        expect(ids).not_to include(unlisted_party.id)
      end
    end

    context 'with raid filter' do
      let(:other_raid) { create(:raid) }
      let!(:other_raid_party) { create(:party, user: user, visibility: 1, raid: other_raid) }

      it 'filters parties by raid' do
        get "/api/v1/users/#{user.username}/parties", params: { raid: raid.id }, headers: auth_headers
        expect(response).to have_http_status(:ok)

        ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(ids).to include(public_party.id)
        expect(ids).not_to include(other_raid_party.id)
      end
    end

    context 'pagination' do
      it 'includes pagination metadata' do
        get "/api/v1/users/#{user.username}/parties", headers: auth_headers
        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body).to have_key('meta')
        expect(body['meta']).to include('count', 'total_pages', 'per_page')
      end
    end

    context 'with nonexistent user' do
      it 'returns 404' do
        get '/api/v1/users/nonexistent/parties', headers: unauth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
