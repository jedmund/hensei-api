# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GridCharacters API', type: :request do
  let(:user) { create(:user) }
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
      'Content-Type' => 'application/json'
    }
  end

  # Using canonical data from CSV for non-user-generated models.
  let(:incoming_character) { Character.find_by(granblue_id: '3040036000') }

  describe 'Authorization for editing grid characters' do
    context 'when the party is owned by a logged in user' do
      let(:valid_params) do
        {
          character: {
            party_id: party.id,
            character_id: incoming_character.id,
            position: 1,
            uncap_level: 3,
            transcendence_step: 0,
            perpetuity: false,
            rings: [{ modifier: '1', strength: '1500' }],
            awakening: { id: 'character-balanced', level: 1 }
          }
        }
      end

      it 'allows the owner to create a grid character' do
        expect do
          post '/api/v1/characters', params: valid_params.to_json, headers: headers
        end.to change(GridCharacter, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'allows the owner to update a grid character' do
        grid_character = create(:grid_character,
                                party: party,
                                character: incoming_character,
                                position: 2,
                                uncap_level: 3,
                                transcendence_step: 0)
        update_params = {
          character: {
            id: grid_character.id,
            party_id: party.id,
            character_id: incoming_character.id,
            position: 2,
            uncap_level: 4,
            transcendence_step: 1,
            rings: [{ modifier: '1', strength: '1500' }, { modifier: '2', strength: '750' }],
            awakening: { id: 'character-attack', level: 2 }
          }
        }

        # Use the resource route for update (as defined by resources :grid_characters)
        put "/api/v1/grid_characters/#{grid_character.id}", params: update_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 4, 'transcendence_step' => 1)
      end

      it 'allows the owner to update the uncap level and transcendence step' do
        grid_character = create(:grid_character,
                                party: party,
                                character: incoming_character,
                                position: 3,
                                uncap_level: 3,
                                transcendence_step: 0)
        update_uncap_params = {
          character: {
            id: grid_character.id,
            party_id: party.id,
            character_id: incoming_character.id,
            uncap_level: 5,
            transcendence_step: 1
          }
        }
        post '/api/v1/characters/update_uncap', params: update_uncap_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 5, 'transcendence_step' => 1)
      end

      it 'allows the owner to resolve conflicts by replacing an existing grid character' do
        # Create a conflicting grid character (same character_id) at the target position.
        conflicting_character = create(:grid_character,
                                       party: party,
                                       character: incoming_character,
                                       position: 4,
                                       uncap_level: 3)
        resolve_params = {
          resolve: {
            position: 4,
            incoming: incoming_character.id,
            conflicting: [conflicting_character.id]
          }
        }
        expect do
          post '/api/v1/characters/resolve', params: resolve_params.to_json, headers: headers
        end.to change(GridCharacter, :count).by(0) # one record is destroyed and one is created
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('position' => 4)
        expect { conflicting_character.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'allows the owner to destroy a grid character' do
        grid_character = create(:grid_character,
                                party: party,
                                character: incoming_character,
                                position: 5,
                                uncap_level: 3)
        # Using the custom route for destroy: DELETE '/api/v1/characters'
        expect do
          delete '/api/v1/characters', params: { id: grid_character.id }.to_json, headers: headers
        end.to change(GridCharacter, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the party is anonymous (no user)' do
      let(:anon_party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let(:headers) { { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'anonsecret' } }
      let(:valid_params) do
        {
          character: {
            party_id: anon_party.id,
            character_id: incoming_character.id,
            position: 1,
            uncap_level: 3,
            transcendence_step: 0,
            perpetuity: false,
            rings: [{ modifier: '1', strength: '1500' }],
            awakening: { id: 'character-balanced', level: 1 }
          }
        }
      end

      it 'allows anonymous creation with correct edit_key' do
        expect do
          post '/api/v1/characters', params: valid_params.to_json, headers: headers
        end.to change(GridCharacter, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      context 'when an incorrect edit_key is provided' do
        let(:headers) { super().merge('X-Edit-Key' => 'wrong') }

        it 'returns an unauthorized response' do
          post '/api/v1/characters', params: valid_params.to_json, headers: headers
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'POST /api/v1/characters (create action) with invalid parameters' do
    context 'with missing or invalid required fields' do
      let(:invalid_params) do
        {
          character: {
            party_id: party.id,
            # Missing character_id
            position: 1,
            uncap_level: 2,
            transcendence_step: 0
          }
        }
      end

      it 'returns unprocessable entity status with error messages' do
        post '/api/v1/characters', params: invalid_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        # Verify that the error message on uncap_level includes a specific phrase.
        expect(json_response['errors']['code'].to_s).to eq('no_character_provided')
      end
    end
  end

  describe 'PUT /api/v1/grid_characters/:id (update action)' do
    let!(:grid_character) do
      create(:grid_character,
             party: party,
             character: incoming_character,
             position: 2,
             uncap_level: 3,
             transcendence_step: 0)
    end

    context 'with valid parameters' do
      let(:update_params) do
        {
          character: {
            id: grid_character.id,
            party_id: party.id,
            character_id: incoming_character.id,
            position: 2,
            uncap_level: 4,
            transcendence_step: 1,
            rings: [{ modifier: '1', strength: '1500' }, { modifier: '2', strength: '750' }],
            awakening: { id: 'character-balanced', level: 2 }
          }
        }
      end

      it 'updates the grid character and returns the updated record' do
        put "/api/v1/grid_characters/#{grid_character.id}", params: update_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 4, 'transcendence_step' => 1)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          character: {
            id: grid_character.id,
            party_id: party.id,
            character_id: incoming_character.id,
            position: 2,
            uncap_level: 'invalid',
            transcendence_step: 1
          }
        }
      end

      it 'returns unprocessable entity status with error details' do
        put "/api/v1/grid_characters/#{grid_character.id}", params: invalid_update_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']['uncap_level'].to_s).to include('is not a number')
      end
    end
  end

  describe 'POST /api/v1/characters/update_uncap (update uncap level action)' do
    let!(:grid_character) do
      create(:grid_character,
             party: party,
             character: incoming_character,
             position: 3,
             uncap_level: 3,
             transcendence_step: 0)
    end

    context 'with valid uncap level parameters' do
      let(:update_uncap_params) do
        {
          character: {
            id: grid_character.id,
            party_id: party.id,
            character_id: incoming_character.id,
            uncap_level: 5,
            transcendence_step: 1
          }
        }
      end

      it 'updates the uncap level and transcendence step' do
        post '/api/v1/characters/update_uncap', params: update_uncap_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['grid_character']).to include('uncap_level' => 5, 'transcendence_step' => 1)
      end
    end
  end

  describe 'POST /api/v1/characters/resolve (conflict resolution action)' do
    let!(:conflicting_character) do
      create(:grid_character,
             party: party,
             character: incoming_character,
             position: 4,
             uncap_level: 3)
    end

    let(:resolve_params) do
      {
        resolve: {
          position: 4,
          incoming: incoming_character.id,
          conflicting: [conflicting_character.id]
        }
      }
    end

    it 'resolves conflicts by replacing the existing grid character' do
      expect(GridCharacter.exists?(conflicting_character.id)).to be true
      expect do
        post '/api/v1/characters/resolve', params: resolve_params.to_json, headers: headers
      end.to change(GridCharacter, :count).by(0) # one record deleted, one created
      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['grid_character']).to include('position' => 4)
      expect { conflicting_character.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /api/v1/characters (destroy action)' do
    context 'when the party is owned by a logged in user' do
      let!(:grid_character) do
        create(:grid_character,
               party: party,
               character: incoming_character,
               position: 6,
               uncap_level: 3)
      end

      it 'destroys the grid character and returns a success response' do
        expect do
          delete '/api/v1/characters', params: { id: grid_character.id }.to_json, headers: headers
        end.to change(GridCharacter, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'returns not found when trying to delete a non-existent grid character' do
        delete '/api/v1/characters', params: { id: '00000000-0000-0000-0000-000000000000' }.to_json, headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the party is anonymous' do
      let(:anon_party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let(:headers) { { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'anonsecret' } }
      let!(:grid_character) do
        create(:grid_character,
               party: anon_party,
               character: incoming_character,
               position: 6,
               uncap_level: 3)
      end

      it 'allows anonymous user to destroy the grid character' do
        expect do
          delete '/api/v1/characters', params: { id: grid_character.id }.to_json, headers: headers
        end.to change(GridCharacter, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'prevents deletion when a logged in user attempts to delete an anonymous grid character' do
        auth_headers = headers.except('X-Edit-Key')
        expect do
          delete '/api/v1/characters', params: { id: grid_character.id }.to_json, headers: auth_headers
        end.not_to change(GridCharacter, :count)
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
