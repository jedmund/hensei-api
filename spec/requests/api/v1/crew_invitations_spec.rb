require 'rails_helper'

RSpec.describe 'Api::V1::CrewInvitations', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

  describe 'GET /api/v1/crews/:crew_id/invitations' do
    context 'as officer' do
      let!(:pending_invitation) { create(:crew_invitation, crew: crew, invited_by: user, status: :pending) }
      let!(:accepted_invitation) { create(:crew_invitation, crew: crew, invited_by: user, status: :accepted) }

      it 'returns pending invitations' do
        get "/api/v1/crews/#{crew.id}/invitations", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['invitations'].length).to eq(1)
        expect(json['invitations'][0]['id']).to eq(pending_invitation.id)
      end
    end

    context 'as regular member' do
      let(:actual_captain) { create(:user) }
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: actual_captain, role: :captain) }
      let!(:member_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        get "/api/v1/crews/#{crew.id}/invitations", headers: auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/invitations' do
    let(:invitee) { create(:user) }

    context 'as officer' do
      it 'creates an invitation by user_id' do
        expect {
          post "/api/v1/crews/#{crew.id}/invitations",
               params: { user_id: invitee.id },
               headers: auth_headers
        }.to change(CrewInvitation, :count).by(1)

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['invitation']['user']['id']).to eq(invitee.id)
      end

      it 'creates an invitation by username' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { username: invitee.username },
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end

      it 'returns error for non-existent user' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: SecureRandom.uuid },
             headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end

      it 'returns error for self-invitation' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: user.id },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['code']).to eq('cannot_invite_self')
      end

      it 'returns error if user already in a crew' do
        other_crew = create(:crew)
        create(:crew_membership, crew: other_crew, user: invitee)

        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['code']).to eq('already_in_crew')
      end

      it 'returns error if user already invited' do
        create(:crew_invitation, crew: crew, user: invitee, invited_by: user, status: :pending)

        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id },
             headers: auth_headers

        expect(response).to have_http_status(:conflict)
        json = response.parsed_body
        expect(json['code']).to eq('user_already_invited')
      end
    end

    context 'as vice captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'can create invitations' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id },
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end
    end

    context 'as regular member' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id },
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/invitations/pending' do
    let(:invitee) { create(:user) }
    let(:invitee_token) do
      Doorkeeper::AccessToken.create!(resource_owner_id: invitee.id, expires_in: 30.days, scopes: 'public')
    end
    let(:invitee_headers) { { 'Authorization' => "Bearer #{invitee_token.token}" } }

    let!(:pending1) { create(:crew_invitation, user: invitee, status: :pending) }
    let!(:pending2) { create(:crew_invitation, user: invitee, status: :pending) }
    let!(:expired) { create(:crew_invitation, user: invitee, status: :expired) }

    it 'returns pending invitations for current user' do
      get '/api/v1/invitations/pending', headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['invitations'].length).to eq(2)
    end
  end

  describe 'POST /api/v1/invitations/:id/accept' do
    let(:invitee) { create(:user) }
    let(:invitee_token) do
      Doorkeeper::AccessToken.create!(resource_owner_id: invitee.id, expires_in: 30.days, scopes: 'public')
    end
    let(:invitee_headers) { { 'Authorization' => "Bearer #{invitee_token.token}" } }
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, status: :pending) }

    it 'accepts the invitation and joins the crew' do
      post "/api/v1/invitations/#{invitation.id}/accept", headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['crew']['id']).to eq(crew.id)
      expect(invitation.reload.status).to eq('accepted')
      expect(invitee.reload.crew).to eq(crew)
    end

    it 'returns error for wrong user' do
      post "/api/v1/invitations/#{invitation.id}/accept", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['code']).to eq('invitation_not_found')
    end
  end

  describe 'POST /api/v1/invitations/:id/reject' do
    let(:invitee) { create(:user) }
    let(:invitee_token) do
      Doorkeeper::AccessToken.create!(resource_owner_id: invitee.id, expires_in: 30.days, scopes: 'public')
    end
    let(:invitee_headers) { { 'Authorization' => "Bearer #{invitee_token.token}" } }
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, status: :pending) }

    it 'rejects the invitation' do
      post "/api/v1/invitations/#{invitation.id}/reject", headers: invitee_headers

      expect(response).to have_http_status(:no_content)
      expect(invitation.reload.status).to eq('rejected')
    end

    it 'returns error for wrong user' do
      post "/api/v1/invitations/#{invitation.id}/reject", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['code']).to eq('invitation_not_found')
    end
  end
end
