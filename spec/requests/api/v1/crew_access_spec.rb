# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Crew access rules', type: :request do
  def headers_for(user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  let(:crew) { create(:crew) }
  let(:captain) { create(:user) }
  let!(:captain_membership) { create(:crew_membership, crew: crew, user: captain, role: :captain) }

  describe 'member collections in rosters' do
    let(:weapon) { Weapon.first || create(:weapon) }
    let(:open_member) { create(:user, collection_privacy: :crew_only) }
    let(:private_member) { create(:user, collection_privacy: :private_collection) }

    before do
      create(:crew_membership, crew: crew, user: open_member)
      create(:crew_membership, crew: crew, user: private_member)
      create(:collection_weapon, user: open_member, weapon: weapon)
      create(:collection_weapon, user: private_member, weapon: weapon)
    end

    def weapons_for(members, user)
      members.find { |m| m['user_id'] == user.id }['weapons']
    end

    it 'hides private collections from the crew roster' do
      get '/api/v1/crew/roster', params: { weapon_ids: [weapon.id] }, headers: headers_for(captain)

      expect(response).to have_http_status(:ok)
      members = response.parsed_body['members']
      expect(weapons_for(members, open_member).length).to eq(1)
      expect(weapons_for(members, private_member)).to eq([])
    end

    it 'hides private collections from saved rosters' do
      roster = create(:crew_roster, crew: crew, created_by: captain, items: [{ 'id' => weapon.id, 'type' => 'Weapon' }])

      get "/api/v1/crew/crew_rosters/#{roster.id}", headers: headers_for(open_member)

      expect(response).to have_http_status(:ok)
      members = response.parsed_body['members']
      expect(weapons_for(members, open_member).length).to eq(1)
      expect(weapons_for(members, private_member)).to eq([])
    end

    it 'still shows members their own private collection' do
      roster = create(:crew_roster, crew: crew, created_by: captain, items: [{ 'id' => weapon.id, 'type' => 'Weapon' }])

      get "/api/v1/crew/crew_rosters/#{roster.id}", headers: headers_for(private_member)

      expect(response).to have_http_status(:ok)
      expect(weapons_for(response.parsed_body['members'], private_member).length).to eq(1)
    end
  end

  describe 'reusing crew invitations' do
    let(:invitee) { create(:user) }
    let(:invitation) { create(:crew_invitation, crew: crew, user: invitee, invited_by: captain) }

    it 'cannot accept an invitation again after leaving the crew' do
      post "/api/v1/invitations/#{invitation.id}/accept", headers: headers_for(invitee)
      expect(response).to have_http_status(:ok)

      invitee.reload.active_crew_membership.retire!

      post "/api/v1/invitations/#{invitation.id}/accept", headers: headers_for(invitee)
      expect(response).to have_http_status(:not_found)
      expect(invitee.reload.crew).to be_nil
    end

    it 'cannot accept a rejected invitation' do
      post "/api/v1/invitations/#{invitation.id}/reject", headers: headers_for(invitee)

      post "/api/v1/invitations/#{invitation.id}/accept", headers: headers_for(invitee)
      expect(response).to have_http_status(:not_found)
      expect(invitee.reload.crew).to be_nil
    end
  end
end
