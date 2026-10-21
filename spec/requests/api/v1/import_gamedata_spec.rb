# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Import gamedata', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user) }

  def headers_for(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/import/characters' do
    let!(:base) { create(:character, granblue_id: '3040377000') }
    let!(:style) { create(:character, granblue_id: '3040377000', style_swap: true) }
    let(:payload) { { 'id' => '3040377000', 'style' => '1', 'ability' => { '1' => { 'class_name' => '1640_1' } } } }

    it 'stores the payload as an object' do
      post '/api/v1/import/characters?lang=en', params: payload.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(base.reload.game_raw_en).to eq(payload)
      expect(Source.fetch(base, :game_raw_en)).to have_attributes(body: JSON.generate(Source.canonical(payload)))
      expect(Source.fetch(base, :game_raw_en).fetched_at).to be_present
    end

    it 'puts a style 1 payload on the base row' do
      post '/api/v1/import/characters?lang=jp', params: payload.to_json, headers: headers_for(editor)

      expect(base.reload.game_raw_jp).to eq(payload)
      expect(style.reload.game_raw_jp).to be_nil
    end

    it 'puts a style 2 payload on the style row' do
      style_payload = payload.merge('style' => '2', 'ability' => { '1' => { 'class_name' => '2559_3' } })
      post '/api/v1/import/characters?lang=en', params: style_payload.to_json, headers: headers_for(editor)

      expect(style.reload.game_raw_en).to eq(style_payload)
      expect(base.reload.game_raw_en).to be_nil
    end

    it 'refuses a style 2 payload when there is no style row' do
      solo = create(:character, granblue_id: '3040001000')
      post '/api/v1/import/characters?lang=en', params: { 'id' => '3040001000', 'style' => 2 }.to_json,
                                                headers: headers_for(editor)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('style row missing for 3040001000')
      expect(solo.reload.game_raw_en).to be_nil
    end

    it 'puts a payload without a style on the base row' do
      post '/api/v1/import/characters?lang=en', params: { 'id' => '3040377000' }.to_json, headers: headers_for(editor)

      expect(base.reload.game_raw_en).to eq('id' => '3040377000')
      expect(style.reload.game_raw_en).to be_nil
    end

    it 'rejects a non-editor' do
      post '/api/v1/import/characters?lang=en', params: payload.to_json, headers: headers_for(user)

      expect(response).to have_http_status(:unauthorized)
      expect(base.reload.game_raw_en).to be_nil
    end

    # D39: the game's real JP-mode style-2 capture for Super Cidala.
    context 'with a payload captured in Japanese' do
      let(:fixtures) { Rails.root.join('spec/fixtures/character_skills') }
      # The top-level id is the player's own npc instance id, not the granblue_id.
      let(:jp_payload) do
        JSON.parse(fixtures.join('character-super-cidala-gamedata-jp.json').read).merge('id' => '194127733')
      end

      before do
        Character.without_skill_build do
          style.update!(wiki_raw: fixtures.join('character-super-cidala-wikidata.txt').read, style_name_en: 'Super Cidala')
        end
      end

      it 'stores it as game_raw_jp on the style row, whatever lang says' do
        post '/api/v1/import/characters?lang=en', params: jp_payload.to_json, headers: headers_for(editor)

        expect(response.parsed_body).to eq('message' => 'Character gamedata updated successfully')
        expect(style.reload.game_raw_jp.dig('ability', '1', 'name')).to eq('運気揚々')
        expect(style.game_raw_en).to be_nil
        expect(base.reload.game_raw_jp).to be_nil
      end

      it 'builds the style from it: game icons, action ids, Japanese and English names' do
        post '/api/v1/import/characters?lang=en', params: jp_payload.to_json, headers: headers_for(editor)

        slots = Granblue::Parsers::CharacterSkillParser.new(Character.find(style.id)).graph[:slots]
        firsts = slots.map { |slot| slot[:versions].first[:attrs] }
        abilities = firsts.first(3)

        expect(abilities.map { |a| a[:game_icon] }).to eq(%w[2559_3 2560_3 2561_1])
        expect(abilities.map { |a| a[:game_action_id] }).to eq(%w[244171 244181 244191])
        expect(firsts.map { |a| a[:name_jp] }).to eq(%w[運気揚々 開寅招福 運気下々 寅気上昇 寅神合体 桃色なデート])
        expect(abilities.map { |a| a[:name_en] }).to eq(['Luck Goes Up', 'Bringer of Proarsperity', 'Luck Goes Down'])
      end

      it 'takes English names from name_en when there is no English payload' do
        post '/api/v1/import/characters?lang=en', params: jp_payload.to_json, headers: headers_for(editor)

        data = Granblue::Parsers::CharacterWikiData.new(Character.find(style.id))
        expect(data.game_action('a1')).to include('name' => 'Luck Goes Up', 'class_name' => '2559_3', 'action_id' => '244171')
        expect(data.game_action('a1')['comment']).not_to match(Granblue::GamePayload::JAPANESE)
        expect(data.game_action('sa')).not_to have_key('name') # the support has no name_en
      end

      it 'refuses a style 2 payload when the style row is missing' do
        style.destroy!
        post '/api/v1/import/characters?lang=jp', params: jp_payload.to_json, headers: headers_for(editor)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to eq('style row missing for 3040377000')
      end

      it 'is a 404, not a 500, for a malformed body' do
        post '/api/v1/import/characters?lang=en', params: [1, 2].to_json, headers: headers_for(editor)
        expect(response).to have_http_status(:not_found)

        post '/api/v1/import/characters?lang=en', params: { 'master' => 'x' }.to_json, headers: headers_for(editor)
        expect(response).to have_http_status(:not_found)
      end

      it 'stores a payload whose series_id has an odd shape' do
        post '/api/v1/import/characters?lang=jp', params: jp_payload.merge('series_id' => { 'x' => 1 }).to_json,
                                                  headers: headers_for(editor)
        expect(response).to have_http_status(:ok)
        expect(style.reload.game_raw_jp).to be_present
      end

      it 'falls back to lang only for a payload with no skill names' do
        post '/api/v1/import/characters', params: { 'id' => '3040377000' }.to_json, headers: headers_for(editor)
        expect(response).to have_http_status(:unprocessable_content)

        post '/api/v1/import/characters?lang=jp', params: { 'id' => '3040377000' }.to_json, headers: headers_for(editor)
        expect(base.reload.game_raw_jp).to eq('id' => '3040377000')
      end
    end
  end

  describe 'POST /api/v1/import/weapons' do
    let!(:weapon) { create(:weapon, granblue_id: '1040815000') }
    let(:payload) { { 'id' => '1040815000', 'name' => 'Test' } }

    it 'stores the payload as an object' do
      post '/api/v1/import/weapons?lang=en', params: payload.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(weapon.reload.game_raw_en).to eq(payload)
    end

    it 'rejects a non-editor' do
      post '/api/v1/import/weapons?lang=en', params: payload.to_json, headers: headers_for(user)

      expect(response).to have_http_status(:unauthorized)
      expect(weapon.reload.game_raw_en).to be_nil
    end
  end

  describe 'POST /api/v1/import/summons' do
    let!(:summon) { create(:summon, granblue_id: '2040001000') }
    let(:payload) { { 'id' => '2040001000', 'name' => 'Test' } }

    it 'stores the payload as an object' do
      post '/api/v1/import/summons?lang=jp', params: payload.to_json, headers: headers_for(editor)

      expect(response).to have_http_status(:ok)
      expect(summon.reload.game_raw_jp).to eq(payload)
    end

    it 'rejects a non-editor' do
      post '/api/v1/import/summons?lang=jp', params: payload.to_json, headers: headers_for(user)

      expect(response).to have_http_status(:unauthorized)
      expect(summon.reload.game_raw_jp).to be_nil
    end
  end
end
