# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection - check_updates', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/collection/weapons/check_updates' do
    let(:endpoint) { '/api/v1/collection/weapons/check_updates' }

    let(:weapon) do
      Weapon.find_by(granblue_id: '1040020000') ||
        create(:weapon, granblue_id: '1040020000', name_en: 'Luminiera Sword Omega')
    end

    def game_item(game_id, granblue_id, evolution: 5)
      {
        'param' => { 'id' => game_id, 'image_id' => granblue_id, 'evolution' => evolution, 'phase' => 0 },
        'master' => { 'id' => granblue_id }
      }
    end

    it 'requires authentication' do
      post endpoint, params: { data: { 'list' => [] } }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns bad_request when no data provided' do
      post endpoint, params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns an entry with field-level deltas for a changed weapon' do
      create(:collection_weapon, user: user, weapon: weapon, game_id: '12345', uncap_level: 3)

      payload = { data: { 'list' => [game_item('12345', '1040020000', evolution: 5)] } }
      post endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['updates'].size).to eq(1)

      entry = json['updates'].first
      expect(entry['game_id']).to eq('12345')
      expect(entry['granblue_id']).to eq('1040020000')

      uncap_change = entry['changes'].find { |c| c['field'] == 'uncap_level' }
      expect(uncap_change['label']).to eq('Uncap')
      expect(uncap_change['before']['raw']).to eq(3)
      expect(uncap_change['after']['raw']).to eq(5)
    end

    it 'skips non-owned weapons' do
      weapon
      payload = { data: { 'list' => [game_item('99999', '1040020000')] } }

      post endpoint, params: payload.to_json, headers: headers

      json = response.parsed_body
      expect(json['updates']).to eq([])
    end
  end

  describe 'POST /api/v1/collection/summons/check_updates' do
    let(:endpoint) { '/api/v1/collection/summons/check_updates' }

    let(:summon) do
      Summon.find_by(granblue_id: '2040035000') ||
        create(:summon, granblue_id: '2040035000', name_en: 'Celeste')
    end

    it 'returns an entry with field-level deltas for a changed summon' do
      create(:collection_summon, user: user, summon: summon, game_id: '55555', uncap_level: 3)

      payload = {
        data: {
          'list' => [
            {
              'param' => { 'id' => '55555', 'image_id' => '2040035000', 'evolution' => '4', 'phase' => 0 },
              'master' => { 'id' => '2040035000' }
            }
          ]
        }
      }
      post endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['updates'].size).to eq(1)
      expect(json['updates'].first['changes'].map { |c| c['field'] }).to include('uncap_level')
    end
  end

  describe 'POST /api/v1/collection/characters/check_updates' do
    let(:endpoint) { '/api/v1/collection/characters/check_updates' }
    let!(:awakening) do
      Awakening.find_by(slug: 'character-balanced', object_type: 'Character') ||
        create(:awakening, :for_character, slug: 'character-balanced', name_en: 'Balanced')
    end

    let(:character) do
      Character.find_by(granblue_id: '3040171000') ||
        create(:character, granblue_id: '3040171000', name_en: 'Hallessena')
    end

    it 'returns an entry for a changed character (game format)' do
      create(:collection_character, user: user, character: character, uncap_level: 3, awakening: awakening)

      payload = {
        data: {
          'list' => [
            {
              'master' => { 'id' => character.granblue_id },
              'param' => { 'id' => 123_456, 'evolution' => '5', 'phase' => '0', 'arousal_level' => 1 }
            }
          ]
        }
      }
      post endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['updates'].size).to eq(1)
      expect(json['updates'].first['granblue_id']).to eq(character.granblue_id)
      expect(json['updates'].first['changes'].map { |c| c['field'] }).to include('uncap_level')
    end

    it 'returns an entry for a changed character (stats format)' do
      create(:collection_character, user: user, character: character, awakening: awakening, perpetuity: false)

      payload = {
        data: {
          'list' => [
            { 'granblue_id' => character.granblue_id, 'perpetuity' => true }
          ]
        }
      }
      post endpoint, params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['updates'].size).to eq(1)
      perp = json['updates'].first['changes'].find { |c| c['field'] == 'perpetuity' }
      expect(perp['before']['display']).to eq('No')
      expect(perp['after']['display']).to eq('Yes')
    end
  end
end
