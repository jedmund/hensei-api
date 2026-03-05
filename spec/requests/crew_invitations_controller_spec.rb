require 'rails_helper'

RSpec.describe 'Crew Invitations API', type: :request do
  let(:captain) { create(:user) }
  let(:vice_captain) { create(:user) }
  let(:member) { create(:user) }
  let(:invitee) { create(:user) }
  let(:crew) { create(:crew) }

  let(:captain_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: captain.id, expires_in: 30.days, scopes: 'public')
  end
  let(:vc_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: vice_captain.id, expires_in: 30.days, scopes: 'public')
  end
  let(:member_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: member.id, expires_in: 30.days, scopes: 'public')
  end
  let(:invitee_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: invitee.id, expires_in: 30.days, scopes: 'public')
  end

  let(:captain_headers) do
    { 'Authorization' => "Bearer #{captain_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:vc_headers) do
    { 'Authorization' => "Bearer #{vc_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:member_headers) do
    { 'Authorization' => "Bearer #{member_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:invitee_headers) do
    { 'Authorization' => "Bearer #{invitee_token.token}", 'Content-Type' => 'application/json' }
  end

  before do
    create(:crew_membership, :captain, crew: crew, user: captain)
    create(:crew_membership, :vice_captain, crew: crew, user: vice_captain)
    create(:crew_membership, crew: crew, user: member)
  end

  describe 'GET /api/v1/crews/:crew_id/invitations' do
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    context 'as captain' do
      it 'returns pending invitations' do
        get "/api/v1/crews/#{crew.id}/invitations", headers: captain_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['invitations'].length).to eq(1)
        expect(json['invitations'][0]['user']['username']).to eq(invitee.username)
      end
    end

    context 'as vice captain' do
      it 'returns pending invitations' do
        get "/api/v1/crews/#{crew.id}/invitations", headers: vc_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as regular member' do
      it 'returns unauthorized' do
        get "/api/v1/crews/#{crew.id}/invitations", headers: member_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/invitations' do
    context 'as captain' do
      it 'creates an invitation' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:created)
        json = response.parsed_body
        expect(json['invitation']['user']['username']).to eq(invitee.username)
        expect(json['invitation']['status']).to eq('pending')
      end

      it 'creates an invitation by username' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { username: invitee.username }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:created)
      end

      it 'returns error when user already in a crew' do
        other_crew = create(:crew)
        create(:crew_membership, :captain, crew: other_crew)
        create(:crew_membership, crew: other_crew, user: invitee)

        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['code']).to eq('already_in_crew')
      end

      it 'returns error when inviting self' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: captain.id }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json['code']).to eq('cannot_invite_self')
      end

      it 'returns error when user already has pending invitation' do
        create(:crew_invitation, crew: crew, user: invitee, invited_by: captain)

        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:conflict)
        json = response.parsed_body
        expect(json['code']).to eq('user_already_invited')
      end

      it 'returns not found for non-existent user' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: SecureRandom.uuid }.to_json,
             headers: captain_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as regular member' do
      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/invitations",
             params: { user_id: invitee.id }.to_json,
             headers: member_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/invitations/pending' do
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'returns pending invitations for current user' do
      get '/api/v1/invitations/pending', headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['invitations'].length).to eq(1)
      expect(json['invitations'][0]['crew']['name']).to eq(crew.name)
    end

    it 'does not return expired invitations' do
      invitation.update!(expires_at: 1.day.ago)

      get '/api/v1/invitations/pending', headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['invitations'].length).to eq(0)
    end

    it 'does not return accepted invitations' do
      invitation.update!(status: :accepted)

      get '/api/v1/invitations/pending', headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['invitations'].length).to eq(0)
    end
  end

  describe 'POST /api/v1/invitations/:id/accept' do
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'accepts the invitation and joins the crew' do
      post "/api/v1/invitations/#{invitation.id}/accept", headers: invitee_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['crew']['name']).to eq(crew.name)

      invitee.reload
      expect(invitee.crew).to eq(crew)
      expect(invitee.crew_role).to eq('member')
    end

    it 'returns error when accepting someone else invitation' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      post "/api/v1/invitations/#{invitation.id}/accept", headers: other_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error when invitation is expired' do
      invitation.update!(expires_at: 1.day.ago)

      post "/api/v1/invitations/#{invitation.id}/accept", headers: invitee_headers

      expect(response).to have_http_status(:gone)
      json = response.parsed_body
      expect(json['code']).to eq('invitation_expired')
    end
  end

  describe 'POST /api/v1/invitations/:id/reject' do
    let!(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'rejects the invitation' do
      post "/api/v1/invitations/#{invitation.id}/reject", headers: invitee_headers

      expect(response).to have_http_status(:no_content)
      expect(invitation.reload.status).to eq('rejected')
    end

    it 'returns error when rejecting someone else invitation' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      post "/api/v1/invitations/#{invitation.id}/reject", headers: other_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
