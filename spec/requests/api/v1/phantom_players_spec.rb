require 'rails_helper'

RSpec.describe 'Api::V1::PhantomPlayers', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

  describe 'GET /api/v1/crews/:crew_id/phantom_players' do
    let!(:phantom1) { create(:phantom_player, crew: crew, name: 'Phantom A') }
    let!(:phantom2) { create(:phantom_player, crew: crew, name: 'Phantom B') }

    context 'as crew member' do
      it 'returns all phantom players' do
        get "/api/v1/crews/#{crew.id}/phantom_players", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['phantom_players'].length).to eq(2)
      end
    end

    context 'as non-member' do
      let(:other_user) { create(:user) }
      let(:other_token) do
        Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      end
      let(:other_headers) { { 'Authorization' => "Bearer #{other_token.token}" } }

      it 'returns unauthorized' do
        get "/api/v1/crews/#{crew.id}/phantom_players", headers: other_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/crews/:crew_id/phantom_players/:id' do
    let!(:phantom) { create(:phantom_player, crew: crew) }

    it 'returns the phantom player with scores' do
      get "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['phantom_player']['name']).to eq(phantom.name)
      expect(json['phantom_player']).to have_key('total_score')
    end
  end

  describe 'POST /api/v1/crews/:crew_id/phantom_players' do
    let(:valid_params) do
      {
        phantom_player: {
          name: 'New Phantom',
          granblue_id: '12345678',
          notes: 'Former member'
        }
      }
    end

    context 'as officer' do
      it 'creates a phantom player' do
        expect {
          post "/api/v1/crews/#{crew.id}/phantom_players",
               params: valid_params,
               headers: auth_headers
        }.to change(PhantomPlayer, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['phantom_player']['name']).to eq('New Phantom')
        expect(json['phantom_player']['granblue_id']).to eq('12345678')
      end

      it 'returns validation error for missing name' do
        post "/api/v1/crews/#{crew.id}/phantom_players",
             params: { phantom_player: { name: '' } },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular member' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/phantom_players",
             params: valid_params,
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/crews/:crew_id/phantom_players/:id' do
    let!(:phantom) { create(:phantom_player, crew: crew, name: 'Old Name') }

    context 'as officer' do
      it 'updates the phantom player' do
        put "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}",
            params: { phantom_player: { name: 'New Name' } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['phantom_player']['name']).to eq('New Name')
      end
    end

    context 'as regular member' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        put "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}",
            params: { phantom_player: { name: 'New Name' } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/crews/:crew_id/phantom_players/:id' do
    let!(:phantom) { create(:phantom_player, crew: crew) }

    context 'as officer' do
      it 'deletes the phantom player' do
        expect {
          delete "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}",
                 headers: auth_headers
        }.to change(PhantomPlayer, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        delete "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}",
               headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/phantom_players/:id/assign' do
    let!(:phantom) { create(:phantom_player, crew: crew) }
    let(:target_user) { create(:user) }
    let!(:target_membership) { create(:crew_membership, crew: crew, user: target_user, role: :member) }

    context 'as officer' do
      it 'assigns the phantom to a user' do
        post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/assign",
             params: { user_id: target_user.id },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['phantom_player']['claimed']).to be true
        expect(json['phantom_player']['claimed_by']['id']).to eq(target_user.id)
      end

      it 'returns error for non-crew member' do
        non_member = create(:user)
        post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/assign",
             params: { user_id: non_member.id },
             headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as regular member' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/assign",
             params: { user_id: target_user.id },
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/phantom_players/:id/confirm_claim' do
    let(:claimer) { create(:user) }
    let!(:claimer_membership) { create(:crew_membership, crew: crew, user: claimer, role: :member) }
    let!(:phantom) { create(:phantom_player, crew: crew, claimed_by: claimer) }

    let(:claimer_token) do
      Doorkeeper::AccessToken.create!(resource_owner_id: claimer.id, expires_in: 30.days, scopes: 'public')
    end
    let(:claimer_headers) { { 'Authorization' => "Bearer #{claimer_token.token}" } }

    it 'confirms the claim' do
      post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/confirm_claim",
           headers: claimer_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['phantom_player']['claim_confirmed']).to be true
    end

    it 'returns error for wrong user' do
      post "/api/v1/crews/#{crew.id}/phantom_players/#{phantom.id}/confirm_claim",
           headers: auth_headers

      expect(response).to have_http_status(:forbidden)
      json = response.parsed_body
      expect(json['code']).to eq('not_claimed_by_user')
    end
  end
end
