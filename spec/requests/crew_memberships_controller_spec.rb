require 'rails_helper'

RSpec.describe 'Crew Memberships API', type: :request do
  let(:captain) { create(:user) }
  let(:vice_captain) { create(:user) }
  let(:member) { create(:user) }
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

  let(:captain_headers) do
    { 'Authorization' => "Bearer #{captain_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:vc_headers) do
    { 'Authorization' => "Bearer #{vc_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:member_headers) do
    { 'Authorization' => "Bearer #{member_token.token}", 'Content-Type' => 'application/json' }
  end

  before do
    create(:crew_membership, :captain, crew: crew, user: captain)
    create(:crew_membership, :vice_captain, crew: crew, user: vice_captain)
    create(:crew_membership, crew: crew, user: member)
  end

  describe 'DELETE /api/v1/crews/:crew_id/memberships/:id' do
    context 'as captain' do
      it 'removes a member' do
        membership = crew.crew_memberships.find_by(user: member)

        delete "/api/v1/crews/#{crew.id}/memberships/#{membership.id}", headers: captain_headers

        expect(response).to have_http_status(:no_content)
        membership.reload
        expect(membership.retired).to be true
      end

      it 'cannot remove the captain' do
        captain_membership = crew.crew_memberships.find_by(user: captain)

        delete "/api/v1/crews/#{crew.id}/memberships/#{captain_membership.id}", headers: captain_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Cannot remove the captain from the crew')
      end
    end

    context 'as vice captain' do
      it 'removes a member' do
        membership = crew.crew_memberships.find_by(user: member)

        delete "/api/v1/crews/#{crew.id}/memberships/#{membership.id}", headers: vc_headers

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as member' do
      it 'returns unauthorized' do
        other_member = create(:user)
        create(:crew_membership, crew: crew, user: other_member)
        membership = crew.crew_memberships.find_by(user: other_member)

        delete "/api/v1/crews/#{crew.id}/memberships/#{membership.id}", headers: member_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/crews/:crew_id/memberships/:id/promote' do
    it 'promotes a member to vice captain' do
      membership = crew.crew_memberships.find_by(user: member)

      post "/api/v1/crews/#{crew.id}/memberships/#{membership.id}/promote", headers: captain_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['membership']['role']).to eq('vice_captain')
    end

    it 'returns error when vice captain limit reached' do
      # Add 2 more vice captains (already have 1)
      2.times do
        vc_user = create(:user)
        create(:crew_membership, :vice_captain, crew: crew, user: vc_user)
      end

      membership = crew.crew_memberships.find_by(user: member)

      post "/api/v1/crews/#{crew.id}/memberships/#{membership.id}/promote", headers: captain_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Crew can only have up to 3 vice captains')
    end

    it 'requires captain role' do
      membership = crew.crew_memberships.find_by(user: member)

      post "/api/v1/crews/#{crew.id}/memberships/#{membership.id}/promote", headers: vc_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/crews/:crew_id/memberships/:id/demote' do
    it 'demotes a vice captain to member' do
      membership = crew.crew_memberships.find_by(user: vice_captain)

      post "/api/v1/crews/#{crew.id}/memberships/#{membership.id}/demote", headers: captain_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['membership']['role']).to eq('member')
    end

    it 'cannot demote the captain' do
      captain_membership = crew.crew_memberships.find_by(user: captain)

      post "/api/v1/crews/#{crew.id}/memberships/#{captain_membership.id}/demote", headers: captain_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'requires captain role' do
      membership = crew.crew_memberships.find_by(user: member)

      post "/api/v1/crews/#{crew.id}/memberships/#{membership.id}/demote", headers: vc_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
