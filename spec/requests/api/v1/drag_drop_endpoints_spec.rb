# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Drag Drop API Endpoints', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:anonymous_party) { create(:party, user: nil, edit_key: 'test-edit-key') }

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

  let(:anonymous_headers) do
    {
      'X-Edit-Key' => 'test-edit-key',
      'Content-Type' => 'application/json'
    }
  end

  describe 'GridWeapon Position Updates' do
    let!(:first_weapon) { create(:grid_weapon, party: party, position: 0) }
    let!(:second_weapon) { create(:grid_weapon, party: party, position: 2) }

    describe 'PUT /api/v1/parties/:party_id/grid_weapons/:id/position' do
      context 'with valid parameters' do
        it 'updates weapon position to empty slot' do
          put "/api/v1/parties/#{party.id}/grid_weapons/#{first_weapon.id}/position",
              params: { position: 4, container: 'main' }.to_json,
              headers: headers

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          expect(json['grid_weapon']['position']).to eq(4)
          expect(first_weapon.reload.position).to eq(4)
        end

        it 'returns error when position is occupied' do
          put "/api/v1/parties/#{party.id}/grid_weapons/#{first_weapon.id}/position",
              params: { position: 2 }.to_json,
              headers: headers

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('occupied')
        end

        it 'returns error for invalid position' do
          put "/api/v1/parties/#{party.id}/grid_weapons/#{first_weapon.id}/position",
              params: { position: 20 }.to_json,
              headers: headers

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('Invalid position')
        end
      end

      context 'with anonymous party' do
        let!(:anon_weapon) { create(:grid_weapon, party: anonymous_party, position: 1) }

        it 'allows update with correct edit key' do
          put "/api/v1/parties/#{anonymous_party.id}/grid_weapons/#{anon_weapon.id}/position",
              params: { position: 3 }.to_json,
              headers: anonymous_headers

          expect(response).to have_http_status(:ok)
          expect(anon_weapon.reload.position).to eq(3)
        end

        it 'denies update with wrong edit key' do
          put "/api/v1/parties/#{anonymous_party.id}/grid_weapons/#{anon_weapon.id}/position",
              params: { position: 3 }.to_json,
              headers: { 'X-Edit-Key' => 'wrong-key', 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    describe 'POST /api/v1/parties/:party_id/grid_weapons/swap' do
      it 'swaps two weapon positions' do
        post "/api/v1/parties/#{party.id}/grid_weapons/swap",
             params: { source_id: first_weapon.id, target_id: second_weapon.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['swapped']['source']['position']).to eq(2)
        expect(json['swapped']['target']['position']).to eq(0)

        expect(first_weapon.reload.position).to eq(2)
        expect(second_weapon.reload.position).to eq(0)
      end

      it 'returns error when weapons not found' do
        post "/api/v1/parties/#{party.id}/grid_weapons/swap",
             params: { source_id: 'invalid', target_id: second_weapon.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GridCharacter Position Updates' do
    let!(:first_character) { create(:grid_character, party: party, position: 0) }
    let!(:second_character) { create(:grid_character, party: party, position: 1) }
    let!(:third_character) { create(:grid_character, party: party, position: 2) }

    describe 'PUT /api/v1/parties/:party_id/grid_characters/:id/position' do
      it 'updates character position and maintains sequential filling' do
        put "/api/v1/parties/#{party.id}/grid_characters/#{first_character.id}/position",
            params: { position: 5, container: 'extra' }.to_json,
            headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['grid_character']['position']).to eq(5)
        expect(json['reordered']).to be true

        # Check compaction happened
        expect(second_character.reload.position).to eq(0)
        expect(third_character.reload.position).to eq(1)
      end

      it 'returns error for invalid position' do
        put "/api/v1/parties/#{party.id}/grid_characters/#{first_character.id}/position",
            params: { position: 8 }.to_json,
            headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Invalid position')
      end
    end

    describe 'POST /api/v1/parties/:party_id/grid_characters/swap' do
      it 'swaps two character positions' do
        post "/api/v1/parties/#{party.id}/grid_characters/swap",
             params: { source_id: first_character.id, target_id: third_character.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['swapped']['source']['position']).to eq(2)
        expect(json['swapped']['target']['position']).to eq(0)

        expect(first_character.reload.position).to eq(2)
        expect(third_character.reload.position).to eq(0)
      end
    end
  end

  describe 'GridSummon Position Updates' do
    let!(:first_summon) { create(:grid_summon, party: party, position: 0) }
    let!(:second_summon) { create(:grid_summon, party: party, position: 2) }

    describe 'PUT /api/v1/parties/:party_id/grid_summons/:id/position' do
      it 'updates summon position to empty slot' do
        put "/api/v1/parties/#{party.id}/grid_summons/#{first_summon.id}/position",
            params: { position: 3, container: 'sub' }.to_json,
            headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['grid_summon']['position']).to eq(3)
        expect(first_summon.reload.position).to eq(3)
      end

      it 'returns error for restricted position' do
        put "/api/v1/parties/#{party.id}/grid_summons/#{first_summon.id}/position",
            params: { position: -1 }.to_json, # Main summon position
            headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('restricted position')
      end

      it 'returns error for friend summon position' do
        put "/api/v1/parties/#{party.id}/grid_summons/#{first_summon.id}/position",
            params: { position: 6 }.to_json, # Friend summon position
            headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('restricted position')
      end
    end

    describe 'POST /api/v1/parties/:party_id/grid_summons/swap' do
      it 'swaps two summon positions' do
        post "/api/v1/parties/#{party.id}/grid_summons/swap",
             params: { source_id: first_summon.id, target_id: second_summon.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['swapped']['source']['position']).to eq(2)
        expect(json['swapped']['target']['position']).to eq(0)

        expect(first_summon.reload.position).to eq(2)
        expect(second_summon.reload.position).to eq(0)
      end

      it 'returns error when trying to swap with restricted position' do
        restricted_summon = create(:grid_summon, party: party, position: -1) # Main summon

        post "/api/v1/parties/#{party.id}/grid_summons/swap",
             params: { source_id: first_summon.id, target_id: restricted_summon.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('restricted')
      end
    end
  end

  describe 'Authorization' do
    let(:other_user) { create(:user) }
    let(:other_party) { create(:party, user: other_user) }
    let!(:weapon) { create(:grid_weapon, party: other_party, position: 0) }

    it 'denies access to other users party' do
      put "/api/v1/parties/#{other_party.id}/grid_weapons/#{weapon.id}/position",
          params: { position: 3 }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies swap on other users party' do
      second_weapon = create(:grid_weapon, party: other_party, position: 1)

      post "/api/v1/parties/#{other_party.id}/grid_weapons/swap",
           params: { source_id: weapon.id, target_id: second_weapon.id }.to_json,
           headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
