# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::CrewRosters', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

  let(:crew) { create(:crew) }

  describe 'GET /api/v1/crew/crew_rosters' do
    context 'as captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }
      let!(:fire_roster) { create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Fire') }
      let!(:water_roster) { create(:crew_roster, crew: crew, created_by: user, element: 3, name: 'Water') }

      it 'returns all rosters ordered by element' do
        get '/api/v1/crew/crew_rosters', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        rosters = json['crew_rosters']
        expect(rosters.length).to eq(2)
        expect(rosters.map { |r| r['element'] }).to eq([2, 3])
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }
      let!(:roster) { create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Fire') }

      it 'returns rosters (visible to all crew members)' do
        get '/api/v1/crew/crew_rosters', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['crew_rosters'].length).to eq(1)
      end
    end

    context 'without a crew' do
      it 'returns not found' do
        get '/api/v1/crew/crew_rosters', headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/crew/crew_rosters/:id' do
    let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

    context 'with an empty roster' do
      let!(:roster) { create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Fire') }

      it 'returns the roster with empty items and members' do
        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['roster']['element']).to eq(2)
        expect(json['items']).to eq([])
        expect(json['members']).to eq([])
      end
    end

    context 'with items' do
      let(:character) { create(:character, element: 2, flb: true, transcendence: true, special: false) }
      let(:weapon) { create(:weapon, element: 2, flb: true, ulb: true, transcendence: false) }
      let(:summon) { create(:summon, element: 2, flb: true, ulb: false, transcendence: false) }

      let!(:roster) do
        create(:crew_roster, :with_items, crew: crew, created_by: user, element: 2, name: 'Fire',
                                          characters: [character], weapons: [weapon], summons: [summon])
      end

      it 'returns enriched items with uncap data' do
        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        items = json['items']
        expect(items.length).to eq(3)

        char_item = items.find { |i| i['type'] == 'Character' }
        expect(char_item['granblue_id']).to eq(character.granblue_id)
        expect(char_item['uncap']['flb']).to be true
        expect(char_item['uncap']['transcendence']).to be true
        expect(char_item['special']).to be false

        wpn_item = items.find { |i| i['type'] == 'Weapon' }
        expect(wpn_item['granblue_id']).to eq(weapon.granblue_id)
        expect(wpn_item['uncap']['flb']).to be true
        expect(wpn_item['uncap']['ulb']).to be true
        expect(wpn_item['uncap']['transcendence']).to be false

        smn_item = items.find { |i| i['type'] == 'Summon' }
        expect(smn_item['granblue_id']).to eq(summon.granblue_id)
        expect(smn_item['uncap']['flb']).to be true
        expect(smn_item['uncap']['ulb']).to be false
      end

      it 'preserves item ordering from the roster' do
        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        json = response.parsed_body
        item_ids = json['items'].map { |i| i['id'] }
        roster_ids = roster.items.map { |i| i['id'] }
        expect(item_ids).to eq(roster_ids)
      end
    end

    context 'with member collection data' do
      let(:character) { create(:character, element: 2, flb: true, transcendence: true, special: false) }
      let(:weapon) { create(:weapon, element: 2, flb: true, ulb: true, transcendence: true) }

      let!(:roster) do
        create(:crew_roster, :with_items, crew: crew, created_by: user, element: 2, name: 'Fire',
                                          characters: [character], weapons: [weapon])
      end

      let(:member_user) { create(:user) }
      let!(:member_membership) { create(:crew_membership, crew: crew, user: member_user, role: :member) }

      let!(:collection_char) do
        create(:collection_character, user: member_user, character: character,
                                      uncap_level: 5, transcendence_step: 3)
      end
      let!(:collection_wpn) do
        create(:collection_weapon, user: member_user, weapon: weapon,
                                   uncap_level: 4, transcendence_step: 0)
      end

      it 'returns member ownership with uncap data from both entity and collection' do
        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        json = response.parsed_body
        members = json['members']
        member = members.find { |m| m['user_id'] == member_user.id }
        expect(member).not_to be_nil
        expect(member['username']).to eq(member_user.username)

        char_ownership = member['characters'].find { |c| c['id'] == character.id }
        expect(char_ownership['uncap_level']).to eq(5)
        expect(char_ownership['transcendence_step']).to eq(3)
        expect(char_ownership['flb']).to be true
        expect(char_ownership['transcendence']).to be true
        expect(char_ownership['special']).to be false

        wpn_ownership = member['weapons'].find { |w| w['id'] == weapon.id }
        expect(wpn_ownership['uncap_level']).to eq(4)
        expect(wpn_ownership['transcendence_step']).to eq(0)
        expect(wpn_ownership['flb']).to be true
        expect(wpn_ownership['ulb']).to be true
        expect(wpn_ownership['transcendence']).to be true
      end

      it 'returns empty arrays for members who do not own the items' do
        other_user = create(:user)
        create(:crew_membership, crew: crew, user: other_user, role: :member)

        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        json = response.parsed_body
        non_owner = json['members'].find { |m| m['user_id'] == other_user.id }
        expect(non_owner['characters']).to eq([])
        expect(non_owner['weapons']).to eq([])
      end

      it 'excludes retired members' do
        retired_user = create(:user)
        create(:crew_membership, crew: crew, user: retired_user, role: :member, retired: true)
        create(:collection_character, user: retired_user, character: character, uncap_level: 3)

        get "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers

        json = response.parsed_body
        member_ids = json['members'].map { |m| m['user_id'] }
        expect(member_ids).not_to include(retired_user.id)
      end
    end
  end

  describe 'PUT /api/v1/crew/crew_rosters/:id' do
    let!(:roster) { create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Fire') }
    let(:character) { create(:character, element: 2) }
    let(:weapon) { create(:weapon, element: 2) }

    context 'as captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'updates roster items' do
        put "/api/v1/crew/crew_rosters/#{roster.id}",
            params: { items: [{ id: character.id, type: 'Character' }, { id: weapon.id, type: 'Weapon' }] },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        roster.reload
        expect(roster.items.length).to eq(2)
        expect(roster.items.map { |i| i['type'] }).to contain_exactly('Character', 'Weapon')
      end

      it 'updates roster name' do
        put "/api/v1/crew/crew_rosters/#{roster.id}",
            params: { name: 'Fire GW Roster' },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(roster.reload.name).to eq('Fire GW Roster')
      end

      it 'can clear all items' do
        roster.update!(items: [{ 'id' => character.id, 'type' => 'Character' }])

        put "/api/v1/crew/crew_rosters/#{roster.id}",
            params: { items: [] },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(roster.reload.items).to eq([])
      end
    end

    context 'as vice captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :vice_captain) }

      it 'allows updates (officers can edit)' do
        put "/api/v1/crew/crew_rosters/#{roster.id}",
            params: { items: [{ id: character.id, type: 'Character' }] },
            headers: auth_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        put "/api/v1/crew/crew_rosters/#{roster.id}",
            params: { items: [{ id: character.id, type: 'Character' }] },
            headers: auth_headers

        expect(response).to have_http_status(:unauthorized)
        expect(roster.reload.items).to eq([])
      end
    end
  end

  describe 'DELETE /api/v1/crew/crew_rosters/:id' do
    let!(:roster) { create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Fire') }

    context 'as captain' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :captain) }

      it 'deletes the roster' do
        expect {
          delete "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers
        }.to change(CrewRoster, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as regular member' do
      let!(:membership) { create(:crew_membership, crew: crew, user: user, role: :member) }

      it 'returns unauthorized' do
        expect {
          delete "/api/v1/crew/crew_rosters/#{roster.id}", headers: auth_headers
        }.not_to change(CrewRoster, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
