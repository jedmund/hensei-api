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

    it 'returns null for max_exorcism_level when not set' do
      weapon_without_exorcism = create(:weapon, max_exorcism_level: nil)

      get "/api/v1/weapons/#{weapon_without_exorcism.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['max_exorcism_level']).to be_nil
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
  end
end
