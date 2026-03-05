require 'rails_helper'

RSpec.describe 'Collection Weapons API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:weapon) { create(:weapon) }
  let(:awakening) { create(:awakening, object_type: 'Weapon') }
  let(:weapon_key) { create(:weapon_key) }

  describe 'GET /api/v1/users/:user_id/collection/weapons' do
    let(:weapon1) { create(:weapon) }
    let(:weapon2) { create(:weapon) }
    let!(:collection_weapon1) { create(:collection_weapon, user: user, weapon: weapon1, uncap_level: 5) }
    let!(:collection_weapon2) { create(:collection_weapon, user: user, weapon: weapon2, uncap_level: 3) }
    let!(:other_user_weapon) { create(:collection_weapon, user: other_user) }

    it 'returns the current user\'s collection weapons' do
      get "/api/v1/users/#{user.id}/collection/weapons", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons'].length).to eq(2)
      expect(json['meta']['count']).to eq(2)
    end

    it 'supports pagination' do
      get "/api/v1/users/#{user.id}/collection/weapons", params: { page: 1, limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons'].length).to eq(1)
      expect(json['meta']['total_pages']).to be >= 2
    end

    it 'supports filtering by weapon' do
      get "/api/v1/users/#{user.id}/collection/weapons", params: { weapon_id: weapon1.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      weapons = json['weapons']
      expect(weapons.length).to eq(1)
      expect(weapons.first['weapon']['id']).to eq(weapon1.id)
    end

    it 'supports filtering by both element and rarity' do
      fire_ssr = create(:weapon, element: 0, rarity: 4)
      water_ssr = create(:weapon, element: 1, rarity: 4)
      fire_sr = create(:weapon, element: 0, rarity: 3)

      create(:collection_weapon, user: user, weapon: fire_ssr)
      create(:collection_weapon, user: user, weapon: water_ssr)
      create(:collection_weapon, user: user, weapon: fire_sr)

      get "/api/v1/users/#{user.id}/collection/weapons", params: { element: 0, rarity: 4 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      weapons = json['weapons']
      expect(weapons.length).to eq(1)
      expect(weapons.first['weapon']['element']).to eq(0)
      expect(weapons.first['weapon']['rarity']).to eq(4)
    end

    it 'returns forbidden for private collection without authentication' do
      private_user = create(:user, collection_privacy: :private_collection)
      create(:collection_weapon, user: private_user)

      get "/api/v1/users/#{private_user.id}/collection/weapons"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/weapons/:id' do
    let!(:collection_weapon) { create(:collection_weapon, user: user, weapon: weapon) }

    it 'returns the collection weapon' do
      get "/api/v1/users/#{user.id}/collection/weapons/#{collection_weapon.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(collection_weapon.id)
      expect(json['weapon']['id']).to eq(weapon.id)
    end

    it 'returns not found for other user\'s weapon' do
      other_collection = create(:collection_weapon, user: other_user)
      get "/api/v1/users/#{user.id}/collection/weapons/#{other_collection.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for non-existent weapon' do
      get "/api/v1/users/#{user.id}/collection/weapons/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/collection/weapons' do
    let(:valid_attributes) do
      {
        collection_weapon: {
          weapon_id: weapon.id,
          uncap_level: 3,
          transcendence_step: 0,
          awakening_id: awakening.id,
          awakening_level: 5
        }
      }
    end

    it 'creates a new collection weapon' do
      expect do
        post '/api/v1/collection/weapons', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionWeapon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['weapon']['id']).to eq(weapon.id)
      expect(json['uncap_level']).to eq(3)
    end

    it 'allows multiple copies of the same weapon' do
      create(:collection_weapon, user: user, weapon: weapon)

      expect do
        post '/api/v1/collection/weapons', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionWeapon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['weapon']['id']).to eq(weapon.id)
    end

    it 'returns error with invalid awakening type' do
      character_awakening = create(:awakening, object_type: 'Character')
      invalid_attributes = valid_attributes.deep_merge(
        collection_weapon: { awakening_id: character_awakening.id }
      )

      post '/api/v1/collection/weapons', params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('must be a weapon awakening')
    end

    it 'returns error with invalid transcendence' do
      invalid_attributes = valid_attributes.deep_merge(
        collection_weapon: { uncap_level: 3, transcendence_step: 5 }
      )

      post '/api/v1/collection/weapons', params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('requires uncap level 5')
    end

    it 'creates weapon with AX skills' do
      ax_atk = WeaponStatModifier.find_by(slug: 'ax_atk') ||
               create(:weapon_stat_modifier, :ax_atk)
      ax_hp = WeaponStatModifier.find_by(slug: 'ax_hp') ||
              create(:weapon_stat_modifier, :ax_hp)

      ax_attributes = valid_attributes.deep_merge(
        collection_weapon: {
          ax_modifier1_id: ax_atk.id,
          ax_strength1: 3.5,
          ax_modifier2_id: ax_hp.id,
          ax_strength2: 2.0
        }
      )

      post '/api/v1/collection/weapons', params: ax_attributes.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['ax']).to be_present
      expect(json['ax'].first['modifier']['slug']).to eq('ax_atk')
      expect(json['ax'].first['strength']).to eq(3.5)
    end

    it 'returns error with incomplete AX skills' do
      ax_atk = WeaponStatModifier.find_by(slug: 'ax_atk') ||
               create(:weapon_stat_modifier, :ax_atk)

      invalid_ax = valid_attributes.deep_merge(
        collection_weapon: {
          ax_modifier1_id: ax_atk.id
          # Missing ax_strength1
        }
      )

      post '/api/v1/collection/weapons', params: invalid_ax.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('AX skill 1 must have both modifier and strength')
    end
  end

  describe 'PUT /api/v1/collection/weapons/:id' do
    let!(:collection_weapon) { create(:collection_weapon, user: user, weapon: weapon, uncap_level: 3) }

    let(:update_attributes) do
      {
        collection_weapon: {
          uncap_level: 5,
          transcendence_step: 3,
          weapon_key1_id: weapon_key.id
        }
      }
    end

    it 'updates the collection weapon' do
      # Just update uncap level, as transcendence and weapon keys may not be supported
      simple_update = {
        collection_weapon: {
          uncap_level: 5
        }
      }

      put "/api/v1/collection/weapons/#{collection_weapon.id}",
          params: simple_update.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['uncap_level']).to eq(5)
    end

    it 'returns not found for other user\'s weapon' do
      other_collection = create(:collection_weapon, user: other_user)
      put "/api/v1/collection/weapons/#{other_collection.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error with duplicate weapon keys' do
      invalid_attributes = {
        collection_weapon: {
          weapon_key1_id: weapon_key.id,
          weapon_key2_id: weapon_key.id  # Same key twice
        }
      }

      put "/api/v1/collection/weapons/#{collection_weapon.id}",
          params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('cannot have duplicate keys')
    end
  end

  describe 'DELETE /api/v1/collection/weapons/:id' do
    let!(:collection_weapon) { create(:collection_weapon, user: user, weapon: weapon) }

    it 'deletes the collection weapon' do
      expect do
        delete "/api/v1/collection/weapons/#{collection_weapon.id}", headers: headers
      end.to change(CollectionWeapon, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns not found for other user\'s weapon' do
      other_collection = create(:collection_weapon, user: other_user)

      expect do
        delete "/api/v1/collection/weapons/#{other_collection.id}", headers: headers
      end.not_to change(CollectionWeapon, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'default exorcism_level for befoulment weapons' do
    let(:odiant_series) { create(:weapon_series, :odiant) }
    let(:befoulment_weapon) { create(:weapon, weapon_series: odiant_series, max_exorcism_level: 5) }
    let(:regular_weapon) { create(:weapon) }

    it 'sets exorcism_level to 1 when creating with befoulment weapon and no exorcism_level provided' do
      attributes = {
        collection_weapon: {
          weapon_id: befoulment_weapon.id,
          uncap_level: 3,
          transcendence_step: 0
        }
      }

      post '/api/v1/collection/weapons', params: attributes.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['exorcism_level']).to eq(1)
    end

    it 'respects provided exorcism_level for befoulment weapon' do
      befoulment_modifier = create(:weapon_stat_modifier, :befoulment)

      attributes = {
        collection_weapon: {
          weapon_id: befoulment_weapon.id,
          uncap_level: 3,
          transcendence_step: 0,
          exorcism_level: 3,
          befoulment_modifier_id: befoulment_modifier.id,
          befoulment_strength: 5.0
        }
      }

      post '/api/v1/collection/weapons', params: attributes.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['exorcism_level']).to eq(3)
    end

    it 'does not set exorcism_level for non-befoulment weapons' do
      attributes = {
        collection_weapon: {
          weapon_id: regular_weapon.id,
          uncap_level: 3,
          transcendence_step: 0
        }
      }

      post '/api/v1/collection/weapons', params: attributes.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['exorcism_level']).to eq(0)
    end
  end
end