# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Drag Drop API', type: :request do
  # Create minimal test data without relying on seeds
  let(:user) { User.create!(username: 'testuser', email: 'test@example.com') }

  let(:party) do
    Party.create!(
      user: user,
      name: 'Test Party',
      raid_id: nil,
      element: 0,
      visibility: 'public'
    )
  end

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
    # Create minimal weapon for testing
    let(:weapon) { Weapon.create!(name_en: 'Test Weapon', element: 0, granblue_id: 'test-001') }
    let!(:grid_weapon1) do
      GridWeapon.create!(
        party: party,
        weapon: weapon,
        position: 0,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

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
      let!(:grid_weapon2) do
        GridWeapon.create!(
          party: party,
          weapon: weapon,
          position: 2,
          uncap_level: 3,
          transcendence_step: 0
        )
      end

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
    let(:weapon) { Weapon.create!(name_en: 'Test Weapon', element: 0, granblue_id: 'test-002') }
    let!(:grid_weapon) do
      GridWeapon.create!(
        party: party,
        weapon: weapon,
        position: 0,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

    describe 'POST /api/v1/parties/:id/grid_update' do
      it 'performs move operation' do
        operations = [
          { type: 'move', entity: 'weapon', id: grid_weapon.id, position: 4 }
        ]

        post "/api/v1/parties/#{party.id}/grid_update",
             params: { operations: operations }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['operations_applied']).to eq(1)
        expect(grid_weapon.reload.position).to eq(4)
      end

      it 'validates operations before executing' do
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
    let(:other_user) { User.create!(username: 'other', email: 'other@example.com') }
    let(:other_party) { Party.create!(user: other_user, name: 'Other Party') }
    let(:weapon) { Weapon.create!(name_en: 'Test Weapon', element: 0, granblue_id: 'test-003') }
    let!(:other_weapon) do
      GridWeapon.create!(
        party: other_party,
        weapon: weapon,
        position: 0,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

    it 'denies access to other users party' do
      put "/api/v1/parties/#{other_party.id}/grid_weapons/#{other_weapon.id}/position",
          params: { position: 3 }.to_json,
          headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end