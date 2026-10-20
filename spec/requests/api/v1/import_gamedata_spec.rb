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
      expect(Character.where(id: base.id).pick(Arel.sql('jsonb_typeof(game_raw_en)'))).to eq('object')
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
