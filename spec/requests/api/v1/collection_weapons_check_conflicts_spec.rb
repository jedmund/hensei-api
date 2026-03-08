# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection Weapons - check_conflicts', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:weapon) do
    Weapon.find_by(granblue_id: '1040020000') ||
      create(:weapon, granblue_id: '1040020000', name_en: 'Luminiera Sword Omega')
  end

  let(:weapon_b) do
    Weapon.find_by(granblue_id: '1040310600') ||
      create(:weapon, granblue_id: '1040310600', name_en: 'Yggdrasil Crystal Blade Omega')
  end

  def game_item(game_id, granblue_id)
    {
      'param' => { 'id' => game_id, 'image_id' => granblue_id, 'evolution' => 3, 'phase' => 0 },
      'master' => { 'id' => granblue_id }
    }
  end

  let(:endpoint) { '/api/v1/collection/weapons/check_conflicts' }

  describe 'POST /api/v1/collection/weapons/check_conflicts' do
    it 'requires authentication' do
      post endpoint, params: { data: { 'list' => [] } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns bad_request when no data provided' do
      post endpoint, params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns empty conflicts when no null-game_id records exist' do
      weapon # ensure weapon exists
      payload = { data: { 'list' => [game_item('12345', '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['conflicts']).to eq([])
    end

    it 'detects a conflict when user has a null-game_id record for the same weapon' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: nil, uncap_level: 2)
      payload = { data: { 'list' => [game_item('12345', '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts'].size).to eq(1)

      conflict = json['conflicts'].first
      expect(conflict['game_id']).to eq('12345')
      expect(conflict['granblue_id']).to eq('1040020000')
      expect(conflict['name']).to eq('Luminiera Sword Omega')
      expect(conflict['existing_uncap_level']).to eq(2)
    end

    it 'does not report a conflict when game_id already matches an existing record' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: '12345', uncap_level: 3)
      payload = { data: { 'list' => [game_item('12345', '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts']).to eq([])
    end

    it 'does not see other users null-game_id records' do
      create(:collection_weapon, user: other_user, weapon: weapon, game_id: nil, uncap_level: 2)
      payload = { data: { 'list' => [game_item('12345', '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts']).to eq([])
    end

    it 'handles multiple items with mixed conflicts' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: nil, uncap_level: 2)
      weapon_b # ensure weapon_b exists, no null record for it
      payload = {
        data: {
          'list' => [
            game_item('12345', '1040020000'),
            game_item('67890', '1040310600')
          ]
        }
      }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts'].size).to eq(1)
      expect(json['conflicts'].first['granblue_id']).to eq('1040020000')
    end

    it 'skips items with no game_id (nil param.id)' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: nil)
      payload = { data: { 'list' => [game_item(nil, '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts']).to eq([])
    end

    it 'skips items whose granblue_id does not match any weapon' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: nil)
      payload = { data: { 'list' => [game_item('12345', '9999999999')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['conflicts']).to eq([])
    end
  end

  describe 'POST /api/v1/collection/weapons/import with conflict_resolutions' do
    let!(:existing_null) do
      create(:collection_weapon, user: user, weapon: weapon, game_id: nil, uncap_level: 2)
    end

    let(:import_endpoint) { '/api/v1/collection/weapons/import' }

    it 'resolves conflict with import and updates the record' do
      payload = {
        data: { 'list' => [game_item('12345', '1040020000')] },
        conflict_resolutions: { '12345' => 'import' }
      }

      expect {
        post import_endpoint, params: payload.to_json, headers: headers
      }.not_to change(user.collection_weapons, :count)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['updated']).to eq(1)
      expect(json['created']).to eq(0)
    end

    it 'resolves conflict with skip and leaves the record alone' do
      payload = {
        data: { 'list' => [game_item('12345', '1040020000')] },
        conflict_resolutions: { '12345' => 'skip' }
      }

      post import_endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['skipped']).to eq(1)
      expect(json['created']).to eq(0)

      existing_null.reload
      expect(existing_null.game_id).to be_nil
      expect(existing_null.uncap_level).to eq(2)
    end
  end
end
