# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Characters', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }
  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 30.days, scopes: 'public')
  end
  let(:user_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:editor_headers) do
    { 'Authorization' => "Bearer #{editor_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:user_headers) do
    { 'Authorization' => "Bearer #{user_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'GET /api/v1/characters/:id' do
    let!(:character) { create(:character) }

    it 'returns the character by uuid with correct fields' do
      get "/api/v1/characters/#{character.id}"
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['id']).to eq(character.id)
      expect(json['name']['en']).to eq(character.name_en)
      expect(json['granblue_id']).to eq(character.granblue_id)
      expect(json['rarity']).to eq(character.rarity)
      expect(json['element']).to eq(character.element)
    end

    it 'returns the character by granblue_id' do
      get "/api/v1/characters/#{character.granblue_id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(character.id)
    end

    it 'returns nested skills in the full character view' do
      status = Status.create!(
        name_en: 'Utopia',
        name_jp: 'ユートピア',
        family: 'Utopia',
        category: 'field',
        icon: 'status_utopia.png'
      )
      skill = CharacterSkill.create!(
        character: character,
        character_granblue_id: character.granblue_id,
        kind: 'ability',
        position: 2,
        game_action_id: '234800'
      )
      version = CharacterSkillVersion.create!(
        character_skill: skill,
        game_action_id: '234811',
        name_en: 'Dazzling Dreams',
        name_jp: 'ドリーム',
        description_en: 'Deploy Utopia.',
        description_jp: 'ユートピアを展開。',
        icon: 'ability_2.png',
        type_color: 'field',
        cooldown: 8,
        initial_cooldown: 3,
        duration_value: 3,
        duration_unit: 'turns',
        variant_role: 'transform_alt',
        ordinal: 1,
        unlock_level: 95,
        enhance_levels: [95],
        min_uncap: 5,
        transcendence_stage: 0,
        trigger_type: 'field_effect',
        trigger_value: 'Utopia active',
        auto_activate: true,
        mimicable: true,
        targets_all: true
      )
      SkillEffect.create!(
        character_skill_version: version,
        status: status,
        ordinal: 0,
        effect_type: 'grant_status',
        target: 'all_allies',
        amount: '30%',
        amount_max: '50%',
        duration_value: 3,
        duration_unit: 'turns',
        accuracy: 'g',
        stacking_frame: 'unique',
        damage_pct: 125.5,
        hit_count: 2,
        damage_cap: 630_000,
        damage_element: 'dark',
        heal_pct: 10.5,
        heal_cap: 2_000
      )

      get "/api/v1/characters/#{character.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['skills'].length).to eq(1)
      expect(json['skills'].first).to include(
        'kind' => 'ability',
        'position' => 2
      )

      version_json = json.dig('skills', 0, 'versions', 0)
      expect(version_json).to include(
        'name' => { 'en' => 'Dazzling Dreams', 'ja' => 'ドリーム' },
        'description' => { 'en' => 'Deploy Utopia.', 'ja' => 'ユートピアを展開。' },
        'icon' => 'ability_2.png',
        'type_color' => 'field',
        'cooldown' => 8,
        'initial_cooldown' => 3,
        'duration_value' => 3,
        'duration_unit' => 'turns',
        'variant_role' => 'transform_alt',
        'ordinal' => 1,
        'unlock_level' => 95,
        'enhance_levels' => [95],
        'min_uncap' => 5,
        'transcendence_stage' => 0,
        'trigger_type' => 'field_effect',
        'trigger_value' => 'Utopia active',
        'auto_activate' => true,
        'mimicable' => true,
        'targets_all' => true
      )

      effect_json = version_json['skill_effects'].first
      expect(effect_json).to include(
        'ordinal' => 0,
        'effect_type' => 'grant_status',
        'target' => 'all_allies',
        'amount' => '30%',
        'amount_max' => '50%',
        'duration_value' => 3,
        'duration_unit' => 'turns',
        'accuracy' => 'g',
        'stacking_frame' => 'unique',
        'hit_count' => 2,
        'damage_cap' => 630_000,
        'damage_element' => 'dark',
        'heal_cap' => 2_000
      )
      expect(effect_json['status']).to include(
        'id' => status.id,
        'name' => { 'en' => 'Utopia', 'ja' => 'ユートピア' },
        'family' => 'Utopia',
        'category' => 'field',
        'icon' => 'status_utopia.png'
      )
    end

    it 'returns skill_links edges between versions in the full character view' do
      skill = create(:character_skill, character: character, kind: 'ability', position: 1)
      base = create(:character_skill_version, character_skill: skill, name_en: 'Base', ordinal: 1)
      alt = create(:character_skill_version, :transform_alt, character_skill: skill, name_en: 'Alt', ordinal: 2)
      create(:character_skill_version_link, from_version: base, to_version: alt, relation: 'transforms_to')

      get "/api/v1/characters/#{character.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['skill_links']).to eq(
        [{ 'from' => base.id, 'to' => alt.id, 'relation' => 'transforms_to' }]
      )
    end

    it 'returns 404 for non-existent id' do
      get '/api/v1/characters/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/characters/:id/related' do
    it 'returns related characters with same character_id' do
      char1 = create(:character, character_id: %w[1234])
      create(:character, character_id: %w[1234])
      get "/api/v1/characters/#{char1.id}/related"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.length).to eq(1)
    end

    it 'returns empty when no related characters exist' do
      char = create(:character, character_id: %w[9999])
      get "/api/v1/characters/#{char.id}/related"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  describe 'POST /api/v1/characters' do
    let(:valid_params) do
      {
        character: {
          granblue_id: '3040999000', name_en: 'Test Character', name_jp: 'テストキャラ',
          rarity: 3, element: 1, proficiency1: 1
        }
      }
    end

    it 'creates a character as editor and returns it' do
      expect {
        post '/api/v1/characters', params: valid_params.to_json, headers: editor_headers
      }.to change(Character, :count).by(1)
      expect(response).to have_http_status(:created)

      json = response.parsed_body
      expect(json['granblue_id']).to eq('3040999000')
      expect(json['name']['en']).to eq('Test Character')
      expect(json['element']).to eq(1)
    end

    it 'rejects creation by regular user' do
      expect {
        post '/api/v1/characters', params: valid_params.to_json, headers: user_headers
      }.not_to change(Character, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/characters/:id' do
    let!(:character) { create(:character) }

    it 'updates a character as editor and persists changes' do
      put "/api/v1/characters/#{character.id}",
          params: { character: { name_en: 'Updated Name' } }.to_json,
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']['en']).to eq('Updated Name')
      expect(character.reload.name_en).to eq('Updated Name')
    end

    it 'rejects update by regular user' do
      put "/api/v1/characters/#{character.id}",
          params: { character: { name_en: 'Updated Name' } }.to_json,
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/characters/:id/raw' do
    let!(:character) { create(:character) }

    it 'returns raw character data with expected fields' do
      get "/api/v1/characters/#{character.id}/raw"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(character.id)
      expect(json).to have_key('wiki_raw')
    end
  end
end
