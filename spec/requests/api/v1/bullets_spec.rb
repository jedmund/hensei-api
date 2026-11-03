# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Bullets', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user, role: 3) }

  def headers_for(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  let(:editor_headers) { headers_for(editor) }
  let(:user_headers) { headers_for(user) }
  let!(:bullet) { create(:bullet, granblue_id: '90101', slug: 'iron-bullet', name_en: 'Iron Bullet') }

  let(:valid_params) do
    { name_en: 'Rapid Bullet', name_jp: 'ラピッドバレット', granblue_id: '90201', slug: 'rapid-bullet',
      bullet_type: 1, atk: 60, hits_all: false, order: 6, effect_en: 'Double attack up' }
  end

  describe 'GET /api/v1/bullets/:id' do
    it 'finds a bullet by granblue_id or uuid' do
      get "/api/v1/bullets/#{bullet.granblue_id}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(bullet.id)

      get "/api/v1/bullets/#{bullet.id}"
      expect(response.parsed_body['granblue_id']).to eq('90101')
    end

    it 'returns 404 for an unknown id' do
      get '/api/v1/bullets/99999'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/bullets' do
    it 'creates a bullet for an editor' do
      expect do
        post '/api/v1/bullets', params: valid_params.to_json, headers: editor_headers
      end.to change(Bullet, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['effect']['en']).to eq('Double attack up')
    end

    it 'rejects a bad granblue_id, slug, type or ATK with errors by param' do
      post '/api/v1/bullets',
           params: valid_params.merge(granblue_id: '201', slug: 'Rapid Bullet', bullet_type: 9, atk: -5).to_json,
           headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors'].keys).to include('granblue_id', 'slug', 'bullet_type', 'atk')
    end

    it 'rejects a non-editor and a signed-out request' do
      post '/api/v1/bullets', params: valid_params.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
      post '/api/v1/bullets', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
      expect(Bullet.where(slug: 'rapid-bullet')).to be_empty
    end
  end

  describe 'PUT /api/v1/bullets/:id' do
    it 'updates a bullet addressed by granblue_id' do
      put "/api/v1/bullets/#{bullet.granblue_id}", params: { atk: 95, hits_all: true }.to_json,
                                                   headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(bullet.reload).to have_attributes(atk: 95, hits_all: true)
    end

    it 'ignores params outside PERMITTED' do
      put "/api/v1/bullets/#{bullet.granblue_id}", params: { id: SecureRandom.uuid, wiki_raw: 'x' }.to_json,
                                                   headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(bullet.reload.wiki_raw).to be_nil
    end

    it 'rejects a non-editor and leaves the bullet unchanged' do
      put "/api/v1/bullets/#{bullet.granblue_id}", params: { name_en: 'Hijacked' }.to_json, headers: user_headers
      expect(response).to have_http_status(:unauthorized)
      expect(bullet.reload.name_en).to eq('Iron Bullet')
    end
  end

  describe 'DELETE /api/v1/bullets/:id' do
    it 'deletes an unused bullet for an editor' do
      delete "/api/v1/bullets/#{bullet.granblue_id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
      expect(Bullet.exists?(bullet.id)).to be(false)
    end

    it 'refuses to delete a bullet loaded on a weapon, with a message' do
      grid_weapon = create(:grid_weapon)
      GridWeaponBullet.insert!({ grid_weapon_id: grid_weapon.id, bullet_id: bullet.id, position: 0 })
      delete "/api/v1/bullets/#{bullet.granblue_id}", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to include('cannot be deleted')
      expect(Bullet.exists?(bullet.id)).to be(true)
    end

    it 'rejects a non-editor' do
      delete "/api/v1/bullets/#{bullet.granblue_id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
      expect(Bullet.exists?(bullet.id)).to be(true)
    end
  end
end
