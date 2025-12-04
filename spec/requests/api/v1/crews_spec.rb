require 'rails_helper'

RSpec.describe 'Api::V1::Crews', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  describe 'POST /api/v1/crews' do
    let(:valid_params) do
      {
        crew: {
          name: 'Test Crew',
          gamertag: 'TEST',
          description: 'A test crew'
        }
      }
    end

    context 'when user has no crew' do
      it 'creates a crew and makes user captain' do
        expect {
          post '/api/v1/crews', params: valid_params, headers: auth_headers
        }.to change(Crew, :count).by(1)
          .and change(CrewMembership, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['crew']['name']).to eq('Test Crew')
        expect(json['crew']['gamertag']).to eq('TEST')

        expect(user.reload.crew).to be_present
        expect(user.active_crew_membership.role).to eq('captain')
      end

      it 'returns validation error for missing name' do
        post '/api/v1/crews', params: { crew: { name: '' } }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user already has a crew' do
      before do
        crew = create(:crew)
        create(:crew_membership, crew: crew, user: user, role: :captain)
      end

      it 'returns error' do
        post '/api/v1/crews', params: valid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('already_in_crew')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/crews', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/crew' do
    context 'when user has a crew' do
      let(:crew) { create(:crew, name: 'My Crew') }
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'returns the crew' do
        get '/api/v1/crew', headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['crew']['name']).to eq('My Crew')
      end
    end

    context 'when user has no crew' do
      it 'returns not found' do
        get '/api/v1/crew', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT /api/v1/crew' do
    let(:crew) { create(:crew, name: 'Original Name') }

    context 'as captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'updates the crew' do
        put '/api/v1/crew', params: { crew: { name: 'New Name' } }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['crew']['name']).to eq('New Name')
      end
    end

    context 'as vice captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'updates the crew' do
        put '/api/v1/crew', params: { crew: { description: 'Updated' } }, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        put '/api/v1/crew', params: { crew: { name: 'New Name' } }, headers: auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/crew/members' do
    let(:crew) { create(:crew) }
    let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
    let!(:member1) { create(:crew_membership, crew: crew, role: :member) }
    let!(:member2) { create(:crew_membership, crew: crew, role: :vice_captain) }

    it 'returns all active crew members' do
      get '/api/v1/crew/members', headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['members'].length).to eq(3)
    end

    it 'excludes retired members' do
      member1.retire!
      get '/api/v1/crew/members', headers: auth_headers
      json = JSON.parse(response.body)
      expect(json['members'].length).to eq(2)
    end
  end

  describe 'POST /api/v1/crew/leave' do
    let(:crew) { create(:crew) }

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'leaves the crew' do
        post '/api/v1/crew/leave', headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(membership.reload.retired).to be true
        expect(user.reload.crew).to be_nil
      end
    end

    context 'as vice captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'leaves the crew' do
        post '/api/v1/crew/leave', headers: auth_headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'returns error' do
        post '/api/v1/crew/leave', headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('captain_cannot_leave')
      end
    end

    context 'when not in a crew' do
      it 'returns error' do
        post '/api/v1/crew/leave', headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('not_in_crew')
      end
    end
  end

  describe 'POST /api/v1/crews/:id/transfer_captain' do
    let(:crew) { create(:crew) }
    let(:new_captain) { create(:user) }
    let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
    let!(:new_captain_membership) { create(:crew_membership, crew: crew, user: new_captain, role: :member) }

    context 'as captain' do
      it 'transfers captainship to another member' do
        post "/api/v1/crews/#{crew.id}/transfer_captain",
             params: { user_id: new_captain.id },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(captain_membership.reload.role).to eq('vice_captain')
        expect(new_captain_membership.reload.role).to eq('captain')
      end

      it 'returns error for non-existent member' do
        post "/api/v1/crews/#{crew.id}/transfer_captain",
             params: { user_id: SecureRandom.uuid },
             headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('member_not_found')
      end
    end

    context 'as vice captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/transfer_captain",
             params: { user_id: new_captain.id },
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
