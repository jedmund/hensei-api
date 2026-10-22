# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Weapons API', type: :request do
  let(:editor_user) { create(:user, role: 7) }
  let(:regular_user) { create(:user, role: 3) }

  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:regular_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: regular_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:editor_headers) do
    { 'Authorization' => "Bearer #{editor_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:regular_headers) do
    { 'Authorization' => "Bearer #{regular_token.token}", 'Content-Type' => 'application/json' }
  end

  let!(:weapon_series) { create(:weapon_series, :odiant) }
  let!(:weapon) { create(:weapon, weapon_series: weapon_series, max_exorcism_level: 5) }

  describe 'GET /api/v1/weapons/:id' do
    it 'returns the weapon with max_exorcism_level' do
      get "/api/v1/weapons/#{weapon.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to eq(5)
    end

    it 'returns when its wikitext was fetched, which nested weapons leave out' do
      fetched_at = Time.utc(2026, 10, 1, 9)
      weapon.update!(wiki_raw: '{{Weapon}}', wiki_raw_fetched_at: fetched_at)

      get "/api/v1/weapons/#{weapon.id}"

      expect(response.parsed_body['wiki_raw_fetched_at']).to eq(fetched_at.iso8601(3))
      expect(response.parsed_body).to have_key('wiki_raw_jp_fetched_at')
      expect(Api::V1::WeaponBlueprint.render_as_hash(weapon, view: :full)).not_to have_key(:wiki_raw_fetched_at)
    end

    it 'returns null for max_exorcism_level when not set' do
      weapon_without_exorcism = create(:weapon, max_exorcism_level: nil)

      get "/api/v1/weapons/#{weapon_without_exorcism.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to be_nil
    end

    it 'returns recruit metadata needed to distinguish character variants' do
      recruited_character = create(:character, element: 5, season: 4, style_swap: true)
      character_series = create(:character_series, :grand)
      create(:character_series_membership,
             character: recruited_character,
             character_series: character_series)
      weapon.update!(recruits: recruited_character.granblue_id)

      get "/api/v1/weapons/#{weapon.id}"

      expect(response).to have_http_status(:ok)
      recruit = response.parsed_body['recruits']
      expect(recruit).to include(
        'id' => recruited_character.id,
        'granblue_id' => recruited_character.granblue_id,
        'name' => {
          'en' => recruited_character.name_en,
          'ja' => recruited_character.name_jp
        },
        'element' => 5,
        'season' => 4,
        'style_swap' => true
      )
      expect(recruit['series']).to contain_exactly(
        {
          'id' => character_series.id,
          'slug' => character_series.slug,
          'name' => {
            'en' => character_series.name_en,
            'ja' => character_series.name_jp
          }
        }
      )
    end

    it 'returns a null recruit when the weapon does not recruit a character' do
      get "/api/v1/weapons/#{weapon.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['recruits']).to be_nil
    end
  end

  describe 'POST /api/v1/weapons' do
    let(:valid_params) do
      {
        weapon: {
          granblue_id: '1040000001',
          name_en: 'Test Weapon',
          rarity: 4,
          element: 1,
          proficiency: 1,
          max_exorcism_level: 5
        }
      }
    end

    it 'creates a weapon with max_exorcism_level when editor' do
      expect {
        post '/api/v1/weapons', params: valid_params.to_json, headers: editor_headers
      }.to change(Weapon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to eq(5)
      expect(json['granblue_id']).to eq('1040000001')
      expect(json['name']['en']).to eq('Test Weapon')
      expect(json['element']).to eq(1)
    end

    it 'creates a weapon with null max_exorcism_level' do
      params = valid_params.deep_dup
      params[:weapon][:max_exorcism_level] = nil
      params[:weapon][:granblue_id] = '1040000002'

      post '/api/v1/weapons', params: params.to_json, headers: editor_headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to be_nil
    end

    it 'rejects creation from non-editor' do
      expect {
        post '/api/v1/weapons', params: valid_params.to_json, headers: regular_headers
      }.not_to change(Weapon, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH /api/v1/weapons/:id' do
    it 'updates max_exorcism_level and persists changes' do
      patch "/api/v1/weapons/#{weapon.id}",
            params: { weapon: { max_exorcism_level: 3 } }.to_json,
            headers: editor_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to eq(3)
      expect(weapon.reload.max_exorcism_level).to eq(3)
    end

    it 'clears max_exorcism_level when set to null' do
      patch "/api/v1/weapons/#{weapon.id}",
            params: { weapon: { max_exorcism_level: nil } }.to_json,
            headers: editor_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to be_nil
    end

    it 'rejects update from non-editor' do
      patch "/api/v1/weapons/#{weapon.id}",
            params: { weapon: { max_exorcism_level: 3 } }.to_json,
            headers: regular_headers

      expect(response).to have_http_status(:unauthorized)
      expect(weapon.reload.max_exorcism_level).to eq(5)
    end

    context 'when the weapon has stored wikitext' do
      let(:fetched_at) { 2.days.ago.change(usec: 0) }
      let!(:stored) { create(:weapon, wiki_raw: '{{Stored}}', wiki_raw_fetched_at: fetched_at) }

      it 'keeps the wikitext when the update sends a blank one' do
        patch "/api/v1/weapons/#{stored.id}",
              params: { weapon: { name_en: 'Renamed', wiki_raw: '' } }.to_json,
              headers: editor_headers

        expect(response).to have_http_status(:ok)
        stored.reload
        expect(stored.name_en).to eq('Renamed')
        expect(stored.wiki_raw).to eq('{{Stored}}')
        expect(stored.wiki_raw_fetched_at).to eq(fetched_at)
      end

      it 'replaces the wikitext and stamps the fetch date when the update sends new text' do
        patch "/api/v1/weapons/#{stored.id}",
              params: { weapon: { wiki_raw: '{{New}}' } }.to_json,
              headers: editor_headers

        expect(response).to have_http_status(:ok)
        stored.reload
        expect(stored.wiki_raw).to eq('{{New}}')
        expect(stored.wiki_raw_fetched_at).to be > fetched_at
      end
    end
  end

  describe 'GET /api/v1/weapons/:id/raw' do
    it 'returns raw weapon data to an editor' do
      weapon.update!(game_raw_en: { 'id' => weapon.granblue_id, 'name' => 'Sword' })
      get "/api/v1/weapons/#{weapon.id}/raw", headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['game_raw_en']).to eq('id' => weapon.granblue_id, 'name' => 'Sword')
    end

    it 'is for editors only' do
      get "/api/v1/weapons/#{weapon.id}/raw", headers: regular_headers
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/weapons/#{weapon.id}/raw"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
