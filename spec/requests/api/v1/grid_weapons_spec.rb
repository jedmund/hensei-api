# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'GridWeapons API', type: :request do
  let(:user) { create(:user) }
  # By default, we create a party owned by the user with edit_key 'secret'
  let(:party) { create(:party, user: user, edit_key: 'secret') }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(
      resource_owner_id: user.id,
      expires_in: 30.days,
      scopes: 'public'
    )
  end
  let(:headers) do
    {
      'Authorization' => "Bearer #{access_token.token}",
      'Content-Type' => 'application/json',
    }
  end
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:incoming_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  describe 'Authorization for editing grid weapons' do
    context 'when the party is owned by a logged in user' do
      let(:weapon_params) do
        {
          weapon: {
            party_id: party.id,
            weapon_id: weapon.id,
            position: 0,
            mainhand: true,
            uncap_level: 3,
            transcendence_step: 0,
            element: weapon.element,
          }
        }
      end

      it 'allows the owner to create a grid weapon' do
        expect do
          post '/api/v1/grid_weapons', params: weapon_params.to_json, headers: headers
        end.to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'rejects a logged-in user that does not own the party' do
        # Create a party owned by a different user.
        other_user = create(:user)
        party_owned_by_other = create(:party, user: other_user, edit_key: 'secret')
        weapon_params[:weapon][:party_id] = party_owned_by_other.id
        post '/api/v1/grid_weapons', params: weapon_params.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the party is anonymous (no user)' do
      # Override party to be anonymous with its own edit_key.
      let(:headers) { super().merge('X-Edit-Key' => 'anonsecret') }
      let(:party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let(:anon_params) do
        {
          weapon: {
            party_id: party.id,
            weapon_id: weapon.id,
            position: 0,
            mainhand: true,
            uncap_level: 3,
            transcendence_step: 0,
            element: weapon.element,
          }
        }
      end

      it 'allows editing with correct edit_key' do
        expect { post '/api/v1/grid_weapons', params: anon_params.to_json, headers: headers }
          .to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      context 'when an incorrect edit_key is provided' do
        # Override the edit_key (simulate invalid key)
        let(:headers) { super().merge('X-Edit-Key' => 'wrong') }

        it 'returns an unauthorized response' do
          post '/api/v1/grid_weapons', params: anon_params.to_json, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /api/v1/grid_weapons (create action)' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          weapon: {
            party_id: party.id,
            weapon_id: weapon.id,
            position: 0,
            mainhand: true,
            uncap_level: 3,
            transcendence_step: 0,
            element: weapon.element,
            weapon_key1_id: nil,
            weapon_key2_id: nil,
            weapon_key3_id: nil,
            ax_modifier1_id: nil,
            ax_modifier2_id: nil,
            ax_strength1: nil,
            ax_strength2: nil,
            awakening_id: nil,
            awakening_level: 1,
          }
        }
      end

      it 'creates a grid weapon and returns status created' do
        expect { post '/api/v1/grid_weapons', params: valid_params.to_json, headers: headers }
          .to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['grid_weapon']).to include('position' => 0)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          weapon: {
            party_id: party.id,
            weapon_id: nil, # Missing required weapon_id
            position: 0,
            mainhand: true,
            uncap_level: 3,
            transcendence_step: 0
          }
        }
      end

      it 'returns unprocessable entity status with errors' do
        post '/api/v1/grid_weapons', params: invalid_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to be_present
      end
    end

    context 'when unauthorized (invalid edit key)' do
      # For this test, use an anonymous party so that edit key checking is applied.
      let(:party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let(:valid_params) do
        {
          weapon: {
            party_id: party.id,
            weapon_id: weapon.id,
            position: 0,
            mainhand: true,
            uncap_level: 3,
            transcendence_step: 0,
            element: weapon.element,
          }
        }
      end

      let(:unauthorized_headers) { headers.merge('X-Edit-Key' => 'wrong') }

      it 'returns an unauthorized response' do
        post '/api/v1/grid_weapons', params: valid_params.to_json, headers: unauthorized_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/grid_weapons/:id (update action)' do
    let!(:grid_weapon) do
      create(:grid_weapon,
             party: party,
             weapon: weapon,
             position: 2,
             uncap_level: 3,
             transcendence_step: 0,
             mainhand: false)
    end
    let(:update_params) do
      {
        weapon: {
          id: grid_weapon.id,
          party_id: party.id,
          weapon_id: weapon.id,
          position: 2,
          mainhand: false,
          uncap_level: 4,
          transcendence_step: 1,
          element: weapon.element,
          weapon_key1_id: nil,
          weapon_key2_id: nil,
          weapon_key3_id: nil,
          ax_modifier1_id: nil,
          ax_modifier2_id: nil,
          ax_strength1: nil,
          ax_strength2: nil,
          awakening_id: nil,
          awakening_level: 1
        }
      }
    end

    it 'updates the grid weapon and returns the updated record' do
      put "/api/v1/grid_weapons/#{grid_weapon.id}", params: update_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['grid_weapon']).to include('mainhand' => false, 'uncap_level' => 4)
    end
  end

  describe 'POST /api/v1/grid_weapons/update_uncap (update uncap level action)' do
    before do
      # For this test, update the weapon so that its conditions dictate a maximum uncap of 5.
      weapon.update!(flb: false, ulb: true, transcendence: false)
    end
    let!(:grid_weapon) do
      create(:grid_weapon,
             party: party,
             weapon: weapon,
             position: 3,
             uncap_level: 3,
             transcendence_step: 0)
    end
    let(:update_uncap_params) do
      {
        weapon: {
          id: grid_weapon.id, # now nested inside the weapon hash
          party_id: party.id,
          weapon_id: weapon.id,
          uncap_level: 6, # attempt above allowed; should be capped at 5
          transcendence_step: 0
        }
      }
    end

    it 'caps the uncap level at 5' do
      post '/api/v1/grid_weapons/update_uncap', params: update_uncap_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['grid_weapon']).to include('uncap_level' => 5)
    end
  end

  describe 'POST /api/v1/grid_weapons/resolve (conflict resolution action)' do
    let!(:conflicting_weapon) do
      create(:grid_weapon,
             party: party,
             weapon: weapon,
             position: 5,
             uncap_level: 3)
    end

    before do
      # Set up the incoming weapon with flags such that: default uncap is 3,
      # but if flb is true then uncap should become 4.
      incoming_weapon.update!(flb: true, ulb: false, transcendence: false)
    end

    let(:resolve_params) do
      {
        resolve: {
          position: 5,
          incoming: incoming_weapon.id,
          conflicting: [conflicting_weapon.id]
        }
      }
    end

    it 'destroys the conflicting weapon and creates a new one with correct uncap' do
      expect(GridWeapon.exists?(conflicting_weapon.id)).to be true

      expect { post '/api/v1/grid_weapons/resolve', params: resolve_params.to_json, headers: headers }
        .to change(GridWeapon, :count).by(0)
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['grid_weapon']).to include('uncap_level' => 4, 'position' => 5)
      expect { conflicting_weapon.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /api/v1/grid_weapons/:id (destroy action)' do
    context 'when the party is owned by a logged in user' do
      let!(:grid_weapon) do
        create(:grid_weapon,
               party: party,
               weapon: weapon,
               position: 4,
               uncap_level: 3)
      end

      it 'destroys the grid weapon and returns a success response' do
        expect { delete "/api/v1/grid_weapons/#{grid_weapon.id}", headers: headers }
          .to change(GridWeapon, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'returns not found when trying to delete a non-existent grid weapon' do
        delete '/api/v1/grid_weapons/00000000-0000-0000-0000-000000000000', headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the party is anonymous (no user)' do
      # For anonymous users, we override both the party and header edit key.
      let(:headers) { super().merge('X-Edit-Key' => 'anonsecret') }
      let(:party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let!(:grid_weapon) do
        create(:grid_weapon,
               party: party,
               weapon: weapon,
               position: 4,
               uncap_level: 3)
      end

      it 'allows anonymous user to destroy grid weapon with correct edit key' do
        expect { delete "/api/v1/grid_weapons/#{grid_weapon.id}", headers: headers }
          .to change(GridWeapon, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'prevents destruction with incorrect edit key' do
        wrong_headers = headers.merge('X-Edit-Key' => 'wrong')
        delete "/api/v1/grid_weapons/#{grid_weapon.id}", headers: wrong_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'prevents deletion when a logged in user attempts to delete an anonymous grid weapon' do
        # When a logged in user (with an access token) tries to delete a grid weapon
        # that belongs to an anonymous party, authorization should fail.
        auth_headers = headers.except('X-Edit-Key')
        expect { delete "/api/v1/grid_weapons/#{grid_weapon.id}", headers: auth_headers }
          .not_to change(GridWeapon, :count)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'default exorcism_level for befoulment weapons' do
    let(:odiant_series) { create(:weapon_series, :odiant) }
    let(:befoulment_weapon) { create(:weapon, weapon_series: odiant_series, max_exorcism_level: 5) }
    let(:regular_weapon) { create(:weapon) }

    it 'sets exorcism_level to 1 when creating with befoulment weapon and no exorcism_level provided' do
      params = {
        weapon: {
          party_id: party.id,
          weapon_id: befoulment_weapon.id,
          position: 1,
          uncap_level: 3,
          transcendence_step: 0
        }
      }

      post '/api/v1/grid_weapons', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['grid_weapon']['exorcism_level']).to eq(1)
    end

    it 'respects provided exorcism_level for befoulment weapon' do
      befoulment_modifier = create(:weapon_stat_modifier, :befoulment)

      params = {
        weapon: {
          party_id: party.id,
          weapon_id: befoulment_weapon.id,
          position: 1,
          uncap_level: 3,
          transcendence_step: 0,
          exorcism_level: 4,
          befoulment_modifier_id: befoulment_modifier.id,
          befoulment_strength: 5.0
        }
      }

      post '/api/v1/grid_weapons', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['grid_weapon']['exorcism_level']).to eq(4)
    end

    it 'does not set exorcism_level for non-befoulment weapons' do
      params = {
        weapon: {
          party_id: party.id,
          weapon_id: regular_weapon.id,
          position: 1,
          uncap_level: 3,
          transcendence_step: 0
        }
      }

      post '/api/v1/grid_weapons', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['grid_weapon']['exorcism_level']).to eq(0)
    end
  end

  describe 'Conflict detection on create' do
    let(:limited_series) { create(:weapon_series) }
    let(:limited_weapon_a) { create(:weapon, limit: true, weapon_series: limited_series) }
    let(:limited_weapon_b) { create(:weapon, limit: true, weapon_series: limited_series) }

    it 'returns a conflict response for different limited weapons in the same series' do
      create(:grid_weapon, party: party, weapon: limited_weapon_a, position: 1, uncap_level: 3)

      expect do
        post '/api/v1/grid_weapons', params: {
          weapon: { party_id: party.id, weapon_id: limited_weapon_b.id, position: 2, uncap_level: 3 }
        }.to_json, headers: headers
      end.not_to change(GridWeapon, :count)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['conflicts']).to be_an(Array)
      expect(json['conflicts'].length).to eq(1)
      expect(json['incoming']['id']).to eq(limited_weapon_b.id)
      expect(json['position']).to eq(2)
    end

    it 'auto-moves when adding the exact same limited weapon to a new position' do
      create(:grid_weapon, party: party, weapon: limited_weapon_a, position: 1, uncap_level: 3)

      expect do
        post '/api/v1/grid_weapons', params: {
          weapon: { party_id: party.id, weapon_id: limited_weapon_a.id, position: 2, uncap_level: 3 }
        }.to_json, headers: headers
      end.not_to change(GridWeapon, :count)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['grid_weapon']).to include('position' => 2)
    end

    it 'does not flag conflict for non-limited weapons in the same series' do
      non_limited_a = create(:weapon, limit: false, weapon_series: limited_series)
      non_limited_b = create(:weapon, limit: false, weapon_series: limited_series)

      create(:grid_weapon, party: party, weapon: non_limited_a, position: 1, uncap_level: 3)

      expect do
        post '/api/v1/grid_weapons', params: {
          weapon: { party_id: party.id, weapon_id: non_limited_b.id, position: 2, uncap_level: 3 }
        }.to_json, headers: headers
      end.to change(GridWeapon, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'detects opus/draconic cross-series conflict' do
      opus_series = WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus)
      draconic_series = WeaponSeries.find_by(slug: 'draconic') || create(:weapon_series, :draconic)
      opus_weapon = create(:weapon, limit: true, weapon_series: opus_series)
      draconic_weapon = create(:weapon, limit: true, weapon_series: draconic_series)

      create(:grid_weapon, party: party, weapon: opus_weapon, position: 1, uncap_level: 3)

      expect do
        post '/api/v1/grid_weapons', params: {
          weapon: { party_id: party.id, weapon_id: draconic_weapon.id, position: 2, uncap_level: 3 }
        }.to_json, headers: headers
      end.not_to change(GridWeapon, :count)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['conflicts']).to be_an(Array)
    end
  end
end
