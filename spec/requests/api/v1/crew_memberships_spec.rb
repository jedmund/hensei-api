require 'rails_helper'

RSpec.describe 'Api::V1::CrewMemberships', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }
  let(:target_user) { create(:user) }
  let!(:target_membership) { create(:crew_membership, crew: crew, user: target_user, role: :member) }

  describe 'PUT /api/v1/crews/:crew_id/memberships/:id' do
    context 'as captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'updates member role' do
        put "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}",
            params: { membership: { role: 'vice_captain' } },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['membership']['role']).to eq('vice_captain')
      end
    end

    context 'as vice captain' do
      let!(:vc_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'returns unauthorized' do
        put "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}",
            params: { membership: { role: 'vice_captain' } },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/crews/:crew_id/memberships/:id' do
    context 'as captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'removes a member' do
        delete "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}",
               headers: auth_headers

        expect(response).to have_http_status(:no_content)
        expect(target_membership.reload.retired).to be true
      end

      it 'cannot remove self (captain)' do
        delete "/api/v1/crews/#{crew.id}/memberships/#{captain_membership.id}",
               headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('cannot_remove_captain')
      end
    end

    context 'as vice captain' do
      let!(:vc_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'can remove regular members' do
        delete "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}",
               headers: auth_headers

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        delete "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}",
               headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/memberships/:id/promote' do
    context 'as captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'promotes member to vice captain' do
        post "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}/promote",
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['membership']['role']).to eq('vice_captain')
      end

      it 'returns error when VC limit reached' do
        3.times { create(:crew_membership, crew: crew, role: :vice_captain) }

        post "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}/promote",
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('vice_captain_limit')
      end

      it 'cannot promote captain' do
        post "/api/v1/crews/#{crew.id}/memberships/#{captain_membership.id}/promote",
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as vice captain' do
      let!(:vc_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/memberships/#{target_membership.id}/promote",
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/memberships/:id/demote' do
    let!(:vc_target) { create(:crew_membership, crew: crew, role: :vice_captain) }

    context 'as captain' do
      let!(:captain_membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'demotes vice captain to member' do
        post "/api/v1/crews/#{crew.id}/memberships/#{vc_target.id}/demote",
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['membership']['role']).to eq('member')
      end

      it 'cannot demote captain' do
        post "/api/v1/crews/#{crew.id}/memberships/#{captain_membership.id}/demote",
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['code']).to eq('cannot_demote_captain')
      end
    end

    context 'as vice captain' do
      let!(:vc_membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'returns unauthorized' do
        post "/api/v1/crews/#{crew.id}/memberships/#{vc_target.id}/demote",
             headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
