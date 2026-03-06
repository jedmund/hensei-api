# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GridSummons API', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user, edit_key: 'secret') }
  let(:summon) { Summon.find_by(granblue_id: '2040433000') }
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

  describe 'POST /api/v1/grid_summons' do
    let(:valid_params) do
      {
        summon: {
          party_id: party.id,
          summon_id: summon.id,
          position: 0,
          main: true,
          friend: false,
          quick_summon: false,
          uncap_level: 3,
          transcendence_step: 0
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a grid summon and returns status created' do
        expect do
          post '/api/v1/grid_summons', params: valid_params.to_json, headers: headers
        end.to change(GridSummon, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['grid_summon']).to include('position' => 0, 'main' => true)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          summon: {
            party_id: party.id,
            summon_id: summon.id,
            position: 0,
            main: true,
            friend: false,
            quick_summon: false,
            uncap_level: 'invalid',
            transcendence_step: 0
          }
        }
      end

      it 'returns unprocessable entity with uncap_level error' do
        post '/api/v1/grid_summons', params: invalid_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('uncap_level')
      end
    end
  end

  describe 'PUT /api/v1/grid_summons/:id' do
    let!(:grid_summon) do
      create(:grid_summon,
             party: party,
             summon: summon,
             position: 1,
             uncap_level: 3,
             transcendence_step: 0)
    end

    context 'with valid parameters' do
      let(:update_params) do
        {
          summon: {
            id: grid_summon.id,
            party_id: party.id,
            summon_id: summon.id,
            position: 1,
            main: true,
            friend: false,
            quick_summon: false,
            uncap_level: 4,
            transcendence_step: 0
          }
        }
      end

      it 'updates the grid summon and returns the updated record' do
        put "/api/v1/grid_summons/#{grid_summon.id}", params: update_params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['grid_summon']).to include('uncap_level' => 4)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          summon: {
            id: grid_summon.id,
            party_id: party.id,
            summon_id: summon.id,
            position: 1,
            main: true,
            friend: false,
            quick_summon: false,
            uncap_level: 'invalid',
            transcendence_step: 0
          }
        }
      end

      it 'returns unprocessable entity with uncap_level error' do
        put "/api/v1/grid_summons/#{grid_summon.id}", params: invalid_update_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to include('uncap_level')
      end
    end
  end

  describe 'POST /api/v1/grid_summons/update_uncap' do
    context 'when summon has flb true, ulb false, transcendence false (max uncap 4)' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 2, uncap_level: 3, transcendence_step: 0)
      end

      before { summon.update!(flb: true, ulb: false, transcendence: false) }

      it 'caps the uncap level at 4' do
        params = { summon: { id: grid_summon.id, party_id: party.id, summon_id: summon.id, uncap_level: 5, transcendence_step: 0 } }
        post '/api/v1/grid_summons/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['grid_summon']).to include('uncap_level' => 4)
      end
    end

    context 'when summon has ulb true, transcendence false (max uncap 5)' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 2, uncap_level: 3, transcendence_step: 0)
      end

      before { summon.update!(flb: true, ulb: true, transcendence: false) }

      it 'caps the uncap level at 5' do
        params = { summon: { id: grid_summon.id, party_id: party.id, summon_id: summon.id, uncap_level: 6, transcendence_step: 0 } }
        post '/api/v1/grid_summons/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['grid_summon']).to include('uncap_level' => 5)
      end
    end

    context 'when summon can be transcended (max uncap 6)' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 2, uncap_level: 3, transcendence_step: 0)
      end

      before { summon.update!(flb: true, ulb: true, transcendence: true) }

      it 'caps the uncap level at 6' do
        params = { summon: { id: grid_summon.id, party_id: party.id, summon_id: summon.id, uncap_level: 7, transcendence_step: 0 } }
        post '/api/v1/grid_summons/update_uncap', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['grid_summon']).to include('uncap_level' => 6)
      end
    end
  end

  describe 'POST /api/v1/grid_summons/update_quick_summon' do
    context 'when grid summon position is not in [4,5,6]' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 2, quick_summon: false)
      end

      it 'updates the quick summon flag and returns the summons array' do
        params = { summon: { id: grid_summon.id, party_id: party.id, summon_id: summon.id, quick_summon: true } }
        post '/api/v1/grid_summons/update_quick_summon', params: params.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['summons']).to be_an(Array)
      end
    end

    context 'when grid summon position is in [4,5,6]' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 4, quick_summon: false)
      end

      it 'returns no content' do
        params = { summon: { id: grid_summon.id, party_id: party.id, summon_id: summon.id, quick_summon: true } }
        post '/api/v1/grid_summons/update_quick_summon', params: params.to_json, headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'DELETE /api/v1/grid_summons/:id' do
    context 'when the party is owned by a logged in user' do
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 3, uncap_level: 3, transcendence_step: 0)
      end

      it 'destroys the grid summon' do
        expect { delete "/api/v1/grid_summons/#{grid_summon.id}", headers: headers }
          .to change(GridSummon, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'returns not found for a non-existent grid summon' do
        delete '/api/v1/grid_summons/00000000-0000-0000-0000-000000000000', headers: headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the party is anonymous (no user)' do
      let(:headers) { super().merge('X-Edit-Key' => 'anonsecret') }
      let(:party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let!(:grid_summon) do
        create(:grid_summon, party: party, summon: summon, position: 3, uncap_level: 3, transcendence_step: 0)
      end

      it 'allows anonymous user to destroy grid summon with correct edit key' do
        anonymous_headers = headers.except('Authorization')
        expect { delete "/api/v1/grid_summons/#{grid_summon.id}", headers: anonymous_headers }
          .to change(GridSummon, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      it 'prevents deletion when a logged in user attempts to delete an anonymous grid summon' do
        auth_headers = headers.except('X-Edit-Key')
        expect { delete "/api/v1/grid_summons/#{grid_summon.id}", headers: auth_headers }
          .not_to change(GridSummon, :count)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
