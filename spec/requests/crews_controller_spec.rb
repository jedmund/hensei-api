require 'rails_helper'

RSpec.describe 'Crews API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:other_access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:other_headers) do
    { 'Authorization' => "Bearer #{other_access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/crews' do
    let(:valid_params) do
      {
        crew: {
          name: 'Test Crew',
          gamertag: 'TEST',
          granblue_crew_id: '12345678',
          description: 'A test crew'
        }
      }
    end

    it 'creates a crew and makes user captain' do
      post '/api/v1/crews', params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['crew']['name']).to eq('Test Crew')
      expect(json['crew']['gamertag']).to eq('TEST')

      user.reload
      expect(user.crew).to be_present
      expect(user.crew_captain?).to be true
    end

    it 'returns error if user already in a crew' do
      crew = create(:crew)
      create(:crew_membership, :captain, crew: crew, user: user)

      post '/api/v1/crews', params: valid_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['message']).to eq('You are already in a crew')
    end

    it 'returns unauthorized without authentication' do
      post '/api/v1/crews', params: valid_params.to_json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'validates crew name presence' do
      invalid_params = { crew: { name: '' } }
      post '/api/v1/crews', params: invalid_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/crew' do
    let(:crew) { create(:crew) }

    before do
      create(:crew_membership, :captain, crew: crew, user: user)
    end

    it 'returns the current user crew' do
      get '/api/v1/crew', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['crew']['name']).to eq(crew.name)
    end

    it 'returns 404 if user has no crew' do
      user.active_crew_membership.retire!

      get '/api/v1/crew', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns unauthorized without authentication' do
      get '/api/v1/crew'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/crew' do
    let(:crew) { create(:crew) }

    context 'as captain' do
      before do
        create(:crew_membership, :captain, crew: crew, user: user)
      end

      it 'updates the crew' do
        put '/api/v1/crew', params: { crew: { name: 'New Name' } }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['crew']['name']).to eq('New Name')
      end
    end

    context 'as vice captain' do
      before do
        create(:crew_membership, :captain, crew: crew)
        create(:crew_membership, :vice_captain, crew: crew, user: user)
      end

      it 'updates the crew' do
        put '/api/v1/crew', params: { crew: { name: 'New Name' } }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as member' do
      before do
        create(:crew_membership, :captain, crew: crew)
        create(:crew_membership, crew: crew, user: user)
      end

      it 'returns unauthorized' do
        put '/api/v1/crew', params: { crew: { name: 'New Name' } }.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/crew/members' do
    let(:crew) { create(:crew) }
    let(:captain) { create(:user) }
    let(:member) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: captain)
      create(:crew_membership, crew: crew, user: user)
      create(:crew_membership, crew: crew, user: member)
    end

    it 'returns all active members' do
      get '/api/v1/crew/members', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['members'].length).to eq(3)
    end

    it 'does not include retired members' do
      crew.crew_memberships.find_by(user: member).retire!

      get '/api/v1/crew/members', headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['members'].length).to eq(2)
    end
  end

  describe 'POST /api/v1/crew/leave' do
    let(:crew) { create(:crew) }

    context 'as regular member' do
      before do
        create(:crew_membership, :captain, crew: crew)
        create(:crew_membership, crew: crew, user: user)
      end

      it 'retires the membership' do
        post '/api/v1/crew/leave', headers: headers

        expect(response).to have_http_status(:no_content)
        user.reload
        expect(user.crew).to be_nil
      end
    end

    context 'as captain' do
      before do
        create(:crew_membership, :captain, crew: crew, user: user)
      end

      it 'returns error' do
        post '/api/v1/crew/leave', headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['message']).to eq('Captain must transfer ownership before leaving')
      end
    end

    context 'when not in crew' do
      it 'returns error' do
        post '/api/v1/crew/leave', headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/v1/crews/:id/transfer_captain' do
    let(:crew) { create(:crew) }
    let(:vice_captain) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: user)
      create(:crew_membership, :vice_captain, crew: crew, user: vice_captain)
    end

    it 'transfers captain role to another member' do
      post "/api/v1/crews/#{crew.id}/transfer_captain",
           params: { user_id: vice_captain.id }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      user.reload
      vice_captain.reload
      expect(user.crew_role).to eq('vice_captain')
      expect(vice_captain.crew_role).to eq('captain')
    end

    it 'returns error if target user is not in crew' do
      post "/api/v1/crews/#{crew.id}/transfer_captain",
           params: { user_id: other_user.id }.to_json,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'requires captain role' do
      create(:crew_membership, crew: crew, user: other_user)

      post "/api/v1/crews/#{crew.id}/transfer_captain",
           params: { user_id: vice_captain.id }.to_json,
           headers: other_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
