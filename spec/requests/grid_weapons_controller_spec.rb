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
          post '/api/v1/weapons', params: weapon_params.to_json, headers: headers
        end.to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'rejects a logged-in user that does not own the party' do
        # Create a party owned by a different user.
        other_user = create(:user)
        party_owned_by_other = create(:party, user: other_user, edit_key: 'secret')
        weapon_params[:weapon][:party_id] = party_owned_by_other.id
        post '/api/v1/weapons', params: weapon_params.to_json, headers: headers
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
        expect { post '/api/v1/weapons', params: anon_params.to_json, headers: headers }
          .to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      context 'when an incorrect edit_key is provided' do
        # Override the edit_key (simulate invalid key)
        let(:headers) { super().merge('X-Edit-Key' => 'wrong') }

        it 'returns an unauthorized response' do
          post '/api/v1/weapons', params: anon_params.to_json, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /api/v1/weapons (create action)' do
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
            ax_modifier1: nil,
            ax_modifier2: nil,
            ax_strength1: nil,
            ax_strength2: nil,
            awakening_id: nil,
            awakening_level: 1,
          }
        }
      end

      it 'creates a grid weapon and returns status created' do
        expect { post '/api/v1/weapons', params: valid_params.to_json, headers: headers }
          .to change(GridWeapon, :count).by(1)
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('grid_weapon')
        expect(json_response['grid_weapon']).to include('position' => 0)
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
        post '/api/v1/weapons', params: invalid_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
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
        post '/api/v1/weapons', params: valid_params.to_json, headers: unauthorized_headers
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
          ax_modifier1: nil,
          ax_modifier2: nil,
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
      json_response = JSON.parse(response.body)
      expect(json_response['grid_weapon']).to include('mainhand' => false, 'uncap_level' => 4)
    end
  end

  describe 'POST /api/v1/weapons/update_uncap (update uncap level action)' do
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

    it 'updates the uncap level to 5 for the grid weapon' do
      post '/api/v1/weapons/update_uncap', params: update_uncap_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['grid_weapon']).to include('uncap_level' => 5)
    end
  end

  describe 'POST /api/v1/weapons/resolve (conflict resolution action)' do
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

    it 'resolves conflicts by destroying conflicting grid weapons and creating a new one' do
      expect(GridWeapon.exists?(conflicting_weapon.id)).to be true

      # The net change should be zero: one grid weapon is destroyed and one is created.
      expect { post '/api/v1/weapons/resolve', params: resolve_params.to_json, headers: headers }
        .to change(GridWeapon, :count).by(0)
      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('grid_weapon')
      # According to the controller logic, with incoming.flb true, the uncap level should be 4.
      expect(json_response['grid_weapon']).to include('uncap_level' => 4)
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

  # Debug hook: if any example fails and a response exists, print the error message.
  after(:each) do |example|
    if example.exception && defined?(response) && response.present?
      error_message = begin
                        JSON.parse(response.body)['exception']
                      rescue JSON::ParserError
                        response.body
                      end
      puts "\nDEBUG: Error Message for '#{example.full_description}': #{error_message}"
      # Parse once and grab the trace safely
      parsed_body = JSON.parse(response.body)
      trace = parsed_body.dig('traces', 'Application Trace')
      ap trace if trace # Only print if trace is not nil
    end
  end
end
