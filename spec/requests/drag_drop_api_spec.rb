# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Drag Drop API', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
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

  describe 'GridWeapon endpoints' do
    let!(:grid_weapon1) { create(:grid_weapon, party: party, position: 0) }

    describe 'PUT /api/v1/parties/:party_id/grid_weapons/:id/position' do
      it 'updates position when valid' do
        put "/api/v1/parties/#{party.id}/grid_weapons/#{grid_weapon1.id}/position",
            params: { position: 3 }.to_json,
            headers: headers

        expect(response).to have_http_status(:ok)
        expect(grid_weapon1.reload.position).to eq(3)
      end

      it 'returns error for invalid position' do
        put "/api/v1/parties/#{party.id}/grid_weapons/#{grid_weapon1.id}/position",
            params: { position: 20 }.to_json,
            headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'POST /api/v1/parties/:party_id/grid_weapons/swap' do
      let!(:grid_weapon2) { create(:grid_weapon, party: party, position: 2) }

      it 'swaps positions of two weapons' do
        post "/api/v1/parties/#{party.id}/grid_weapons/swap",
             params: { source_id: grid_weapon1.id, target_id: grid_weapon2.id }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(grid_weapon1.reload.position).to eq(2)
        expect(grid_weapon2.reload.position).to eq(0)
      end
    end
  end

  describe 'Batch Grid Update' do
    let!(:grid_weapon) { create(:grid_weapon, party: party, position: 0) }

    describe 'POST /api/v1/parties/:id/grid_update' do
      it 'performs move operation' do
        operations = [
          { type: 'move', entity: 'weapon', id: grid_weapon.id, position: 4 }
        ]

        post "/api/v1/parties/#{party.id}/grid_update",
             params: { operations: operations }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['operations_applied']).to eq(1)
        expect(grid_weapon.reload.position).to eq(4)
      end

      it 'rejects invalid operation types' do
        operations = [
          { type: 'invalid', entity: 'weapon', id: grid_weapon.id }
        ]

        post "/api/v1/parties/#{party.id}/grid_update",
             params: { operations: operations }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'Authorization' do
    let(:other_user) { create(:user) }
    let(:other_party) { create(:party, user: other_user) }
    let!(:other_weapon) { create(:grid_weapon, party: other_party, position: 0) }

    it 'denies access to other users party' do
      put "/api/v1/parties/#{other_party.id}/grid_weapons/#{other_weapon.id}/position",
          params: { position: 3 }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
