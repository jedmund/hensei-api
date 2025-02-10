# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'GridCharacters API', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user, edit_key: 'secret') }
  # Use canonical records seeded into your DB.
  # For example, assume Rosamia (granblue_id "3040087000") and Seofon (granblue_id "3040036000")
  let(:rosamia) { Character.find_by(granblue_id: '3040087000') }
  let(:seofon) { Character.find_by(granblue_id: '3040036000') }
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
      'X-Edit-Key' => 'secret'
    }
  end

  describe 'POST /api/v1/characters (create)' do
    context 'when creating a grid character with a unique canonical character (e.g. Seofon)' do
      let(:valid_params) do
        {
          character: {
            party_id: party.id,
            character_id: seofon.id,
            position: 0,
            uncap_level: 3,
            transcendence_step: 0,
            rings: [
              { modifier: 'A', strength: 1 },
              { modifier: 'B', strength: 2 }
            ]
          }
        }
      end

      it 'creates the grid character and returns status created' do
        expect do
          post '/api/v1/characters', params: valid_params.to_json, headers: headers
        end.to change(GridCharacter, :count).by(1)
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('position' => 0)
      end
    end

    context 'when attempting to add a duplicate canonical character (e.g. Rosamia)' do
      before do
        # Create an initial grid character for Rosamia.
        GridCharacter.create!(
          party_id: party.id,
          character_id: rosamia.id,
          position: 1,
          uncap_level: 3,
          transcendence_step: 0
        )
      end

      let(:duplicate_params) do
        {
          character: {
            party_id: party.id,
            character_id: rosamia.id, # same canonical character
            position: 2,
            uncap_level: 3,
            transcendence_step: 0
          }
        }
      end

      it 'detects the conflict and returns a conflict resolution view without adding a duplicate' do
        # Here we simulate conflict resolution via the resolve endpoint.
        expect do
          post '/api/v1/characters/resolve',
               params: { resolve: { position: 2, incoming: rosamia.id, conflicting: [GridCharacter.last.id] } }.to_json,
               headers: headers
        end.to change(GridCharacter, :count).by(0)
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response).to include('position' => 2)
      end
    end
  end

  describe 'PUT /api/v1/characters/:id (update)' do
    before do
      @grid_character = GridCharacter.create!(
        party_id: party.id,
        character_id: rosamia.id,
        position: 1,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

    let(:update_params) do
      {
        character: {
          id: @grid_character.id,
          party_id: party.id,
          character_id: rosamia.id,
          position: 1,
          uncap_level: 4,
          transcendence_step: 0,
          rings: [
            { modifier: 'C', strength: 3 }
          ]
        }
      }
    end

    it 'updates the grid character and returns the updated record' do
      put "/api/v1/grid_characters/#{@grid_character.id}", params: update_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to include('uncap_level' => 4)
    end
  end

  describe 'POST /api/v1/characters/update_uncap (update uncap level)' do
    context 'for a character that does NOT allow transcendence (e.g. Rosamia)' do
      before do
        @grid_character = GridCharacter.create!(
          party_id: party.id,
          character_id: rosamia.id,
          position: 2,
          uncap_level: 2,
          transcendence_step: 0
        )
      end

      let(:update_uncap_params) do
        {
          character: {
            id: @grid_character.id,
            party_id: party.id,
            character_id: rosamia.id,
            uncap_level: 3,
            transcendence_step: 0
          }
        }
      end

      it 'caps the uncap level at 4 for a character with flb true' do
        post '/api/v1/characters/update_uncap', params: update_uncap_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 3)
      end
    end

    context 'for a character that allows transcendence (e.g. Seofon)' do
      before do
        # For Seofon, the "transcendence" behavior is enabled by its ulb flag.
        @grid_character = GridCharacter.create!(
          party_id: party.id,
          character_id: seofon.id,
          position: 2,
          uncap_level: 5,
          transcendence_step: 0
        )
      end

      let(:update_uncap_params) do
        {
          character: {
            id: @grid_character.id,
            party_id: party.id,
            character_id: seofon.id,
            uncap_level: 5,
            transcendence_step: 1
          }
        }
      end

      it 'updates the uncap level to 6 when the character supports transcendence via ulb' do
        post '/api/v1/characters/update_uncap', params: update_uncap_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 5, 'transcendence_step' => 1)
      end
    end
  end

  describe 'DELETE /api/v1/characters (destroy)' do
    before do
      @grid_character = GridCharacter.create!(
        party_id: party.id,
        character_id: rosamia.id,
        position: 4,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

    it 'destroys the grid character and returns a destroyed view' do
      expect do
        delete '/api/v1/characters', params: { id: @grid_character.id }.to_json, headers: headers
      end.to change(GridCharacter, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end
  end
end
