# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::UserRaidElements', type: :request do
  let(:fire) { GranblueEnums::ELEMENTS[:Fire] }
  let(:water) { GranblueEnums::ELEMENTS[:Water] }
  let(:earth) { GranblueEnums::ELEMENTS[:Earth] }
  let(:dark) { GranblueEnums::ELEMENTS[:Dark] }

  let(:user) { create(:user) }
  let(:raid) { create(:raid, :trackable) }

  def headers_for(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def sync(elements, raid_id: raid.id, headers: headers_for(user))
    put '/api/v1/user_raid_elements/sync', params: { raid_id: raid_id, elements: elements }.to_json, headers: headers
  end

  describe 'GET /api/v1/user_raid_elements' do
    it 'returns 401 without authentication' do
      get '/api/v1/user_raid_elements'
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user's elements grouped by raid" do
      create(:user_raid_element, user: user, raid: raid, element: earth)
      create(:user_raid_element, user: user, raid: raid, element: fire)
      create(:user_raid_element, user: create(:user), raid: raid, element: dark)

      get '/api/v1/user_raid_elements', headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        {
          'raid_id' => raid.id,
          'raid_name' => { 'en' => raid.name_en, 'ja' => raid.name_jp },
          'elements' => [fire, earth]
        }
      ])
    end

    it 'leaves out raids that are no longer trackable' do
      create(:user_raid_element, user: user, raid: raid, element: fire)
      raid.update!(trackable: false)

      get '/api/v1/user_raid_elements', headers: headers_for(user)

      expect(response.parsed_body).to eq([])
    end
  end

  describe 'PUT /api/v1/user_raid_elements/sync' do
    it 'returns 401 without authentication' do
      sync([fire], headers: { 'Content-Type' => 'application/json' })
      expect(response).to have_http_status(:unauthorized)
    end

    it "replaces the current user's elements for the raid" do
      create(:user_raid_element, user: user, raid: raid, element: fire)

      sync([dark, water])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first['elements']).to eq([water, dark])
      expect(user.user_raid_elements.where(raid: raid).pluck(:element)).to contain_exactly(water, dark)
    end

    it 'dedupes repeated elements' do
      sync([fire, fire, earth])

      expect(response).to have_http_status(:ok)
      expect(user.user_raid_elements.where(raid: raid).pluck(:element)).to contain_exactly(fire, earth)
    end

    it 'clears the raid when given no elements' do
      create(:user_raid_element, user: user, raid: raid, element: fire)

      sync([])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
      expect(user.user_raid_elements.where(raid: raid)).to be_empty
    end

    it "leaves other raids and other users' elements alone" do
      other_raid = create(:raid, :trackable)
      mine_elsewhere = create(:user_raid_element, user: user, raid: other_raid, element: water)
      theirs = create(:user_raid_element, user: create(:user), raid: raid, element: fire)

      sync([earth])

      expect(response).to have_http_status(:ok)
      expect(UserRaidElement.exists?(mine_elsewhere.id)).to be(true)
      expect(UserRaidElement.exists?(theirs.id)).to be(true)
    end

    it 'ignores a user_id in the params' do
      other = create(:user)

      put '/api/v1/user_raid_elements/sync',
          params: { raid_id: raid.id, user_id: other.id, elements: [fire] }.to_json,
          headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(other.user_raid_elements).to be_empty
      expect(user.user_raid_elements.pluck(:element)).to eq([fire])
    end

    it 'returns 422 for a raid that is not trackable' do
      untracked = create(:raid)

      sync([fire], raid_id: untracked.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(UserRaidElement.count).to eq(0)
    end

    it 'returns 422 for an element outside the game elements and keeps existing ones' do
      create(:user_raid_element, user: user, raid: raid, element: fire)

      [[GranblueEnums::ELEMENTS[:Null]], [7], [fire, 'wind'], 'fire'].each do |elements|
        sync(elements)
        expect(response).to have_http_status(:unprocessable_entity), "expected 422 for #{elements.inspect}"
      end

      expect(user.user_raid_elements.pluck(:element)).to eq([fire])
    end

    it 'returns 422 without an elements list' do
      create(:user_raid_element, user: user, raid: raid, element: fire)

      put '/api/v1/user_raid_elements/sync', params: { raid_id: raid.id }.to_json, headers: headers_for(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.user_raid_elements.pluck(:element)).to eq([fire])
    end

    it 'returns 404 for an unknown raid' do
      sync([fire], raid_id: SecureRandom.uuid)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 without a raid_id' do
      put '/api/v1/user_raid_elements/sync', params: { elements: [fire] }.to_json, headers: headers_for(user)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/users/:username/raid_elements' do
    let(:crew) { create(:crew) }
    let(:member) { create(:user) }

    before do
      create(:crew_membership, :captain, crew: crew, user: user)
      create(:crew_membership, crew: crew, user: member)
      create(:user_raid_element, user: member, raid: raid, element: water)
    end

    it 'returns 401 without authentication' do
      get "/api/v1/users/#{member.username}/raid_elements"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns a crewmate's elements" do
      get "/api/v1/users/#{member.username}/raid_elements", headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        {
          'raid_id' => raid.id,
          'raid_name' => { 'en' => raid.name_en, 'ja' => raid.name_jp },
          'elements' => [water]
        }
      ])
    end

    it 'matches the username case-insensitively' do
      get "/api/v1/users/#{member.username.upcase}/raid_elements", headers: headers_for(user)
      expect(response).to have_http_status(:ok)
    end

    it "returns the viewer's own elements without a crew" do
      loner = create(:user)
      create(:user_raid_element, user: loner, raid: raid, element: dark)

      get "/api/v1/users/#{loner.username}/raid_elements", headers: headers_for(loner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first['elements']).to eq([dark])
    end

    it 'returns 403 for a viewer in another crew' do
      outsider = create(:user)
      create(:crew_membership, user: outsider)

      get "/api/v1/users/#{member.username}/raid_elements", headers: headers_for(outsider)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 for a viewer without a crew' do
      get "/api/v1/users/#{member.username}/raid_elements", headers: headers_for(create(:user))
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 once the member has left the crew' do
      member.active_crew_membership.update!(retired: true, retired_at: Time.current)

      get "/api/v1/users/#{member.username}/raid_elements", headers: headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 for an unknown username' do
      get '/api/v1/users/nobody_by_this_name/raid_elements', headers: headers_for(user)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'raid trackable flag' do
    let(:editor) { create(:user, role: 7) }

    it 'is in the raid JSON' do
      get "/api/v1/raids/#{raid.slug}"
      expect(response.parsed_body['trackable']).to be(true)
    end

    it 'filters GET /raids to trackable raids' do
      tracked = raid
      create(:raid)

      get '/api/v1/raids', params: { trackable: 'true' }

      expect(response.parsed_body.pluck('id')).to eq([tracked.id])
    end

    it 'can be set by an editor' do
      untracked = create(:raid)

      put "/api/v1/raids/#{untracked.slug}", params: { raid: { trackable: true } }.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(untracked.reload.trackable).to be(true)
    end

    it 'cannot be set by a regular user' do
      untracked = create(:raid)

      put "/api/v1/raids/#{untracked.slug}", params: { raid: { trackable: true } }.to_json, headers: headers_for(user)

      expect(untracked.reload.trackable).to be(false)
    end
  end
end
