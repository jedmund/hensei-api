# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::UserRaidElements', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 7200, scopes: '')
  end
  let(:auth_headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'GET /api/v1/user_raid_elements' do
    it 'returns 401 without authentication' do
      get '/api/v1/user_raid_elements', headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns empty array when user has no elements' do
      get '/api/v1/user_raid_elements', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'returns elements grouped by raid' do
      raid = create(:raid)
      create(:user_raid_element, user: user, raid: raid, element: 1)
      create(:user_raid_element, user: user, raid: raid, element: 3)

      get '/api/v1/user_raid_elements', headers: auth_headers
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json[0]['raid_id']).to eq(raid.id)
      expect(json[0]['elements']).to match_array([1, 3])
      expect(json[0]['raid_name']['en']).to eq(raid.name_en)
      expect(json[0]['raid_name']['ja']).to eq(raid.name_jp)
    end

    it 'groups elements from multiple raids separately' do
      raid_a = create(:raid)
      raid_b = create(:raid)
      create(:user_raid_element, user: user, raid: raid_a, element: 2)
      create(:user_raid_element, user: user, raid: raid_b, element: 5)
      create(:user_raid_element, user: user, raid: raid_b, element: 6)

      get '/api/v1/user_raid_elements', headers: auth_headers
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to eq(2)

      raid_a_data = json.find { |r| r['raid_id'] == raid_a.id }
      raid_b_data = json.find { |r| r['raid_id'] == raid_b.id }

      expect(raid_a_data['elements']).to eq([2])
      expect(raid_b_data['elements']).to match_array([5, 6])
    end

    it 'does not include other users elements' do
      other_user = create(:user)
      raid = create(:raid)
      create(:user_raid_element, user: other_user, raid: raid, element: 4)

      get '/api/v1/user_raid_elements', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  describe 'PUT /api/v1/user_raid_elements/sync' do
    let(:raid) { create(:raid) }

    it 'returns 401 without authentication' do
      put '/api/v1/user_raid_elements/sync',
          params: { raid_id: raid.id, elements: [1, 2] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates elements for a raid' do
      expect {
        put '/api/v1/user_raid_elements/sync',
            params: { raid_id: raid.id, elements: [1, 3, 5] }.to_json,
            headers: auth_headers
      }.to change(UserRaidElement, :count).by(3)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json[0]['raid_id']).to eq(raid.id)
      expect(json[0]['elements']).to match_array([1, 3, 5])
    end

    it 'replaces existing elements for the raid' do
      create(:user_raid_element, user: user, raid: raid, element: 1)
      create(:user_raid_element, user: user, raid: raid, element: 2)

      put '/api/v1/user_raid_elements/sync',
          params: { raid_id: raid.id, elements: [4, 6] }.to_json,
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json[0]['elements']).to match_array([4, 6])

      remaining = user.user_raid_elements.where(raid: raid).pluck(:element)
      expect(remaining).to match_array([4, 6])
    end

    it 'clears all elements when given an empty array' do
      create(:user_raid_element, user: user, raid: raid, element: 1)
      create(:user_raid_element, user: user, raid: raid, element: 2)

      expect {
        put '/api/v1/user_raid_elements/sync',
            params: { raid_id: raid.id, elements: [] }.to_json,
            headers: auth_headers
      }.to change(UserRaidElement, :count).by(-2)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'does not affect elements for other raids' do
      other_raid = create(:raid)
      create(:user_raid_element, user: user, raid: other_raid, element: 3)

      put '/api/v1/user_raid_elements/sync',
          params: { raid_id: raid.id, elements: [1] }.to_json,
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(user.user_raid_elements.where(raid: other_raid).pluck(:element)).to eq([3])
    end

    it 'returns 404 for a non-existent raid' do
      put '/api/v1/user_raid_elements/sync',
          params: { raid_id: '00000000-0000-0000-0000-000000000000', elements: [1] }.to_json,
          headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/users/:username/raid_elements' do
    it 'returns elements for the specified user' do
      other_user = create(:user)
      raid = create(:raid)
      create(:user_raid_element, user: other_user, raid: raid, element: 2)
      create(:user_raid_element, user: other_user, raid: raid, element: 4)

      get "/api/v1/users/#{other_user.username}/raid_elements"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json[0]['raid_id']).to eq(raid.id)
      expect(json[0]['elements']).to match_array([2, 4])
    end

    it 'returns empty array for user with no elements' do
      other_user = create(:user)

      get "/api/v1/users/#{other_user.username}/raid_elements"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it 'returns 404 for non-existent username' do
      get '/api/v1/users/nonexistent_user_xyz/raid_elements'
      expect(response).to have_http_status(:not_found)
    end

    it 'does not require authentication' do
      other_user = create(:user)
      raid = create(:raid)
      create(:user_raid_element, user: other_user, raid: raid, element: 6)

      get "/api/v1/users/#{other_user.username}/raid_elements"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[0]['elements']).to eq([6])
    end
  end
end
