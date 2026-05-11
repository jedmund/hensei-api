# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Substitutions API', type: :request do
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
  let(:weapon) { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  describe 'POST /api/v1/substitutions' do
    let(:grid_weapon) { create(:grid_weapon, party: party, weapon: weapon) }

    it 'creates a substitution and a substitute grid item' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      expect do
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      end.to change(Substitution, :count).by(1)
                                         .and change(GridWeapon, :count).by(1)

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)
      expect(body['position']).to eq(0)
      # Polymorphic substitute_grid renders under the per-type key the frontend reads.
      expect(body).to have_key('grid_weapon')
    end

    it 'renders a character substitute under the grid_character key' do
      character = Character.first
      other_character = Character.where.not(id: character.id).first
      grid_character = create(:grid_character, party: party, character: character)

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridCharacter',
          grid_id: grid_character.id,
          item_id: other_character.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers
      body = JSON.parse(response.body)
      expect(body).to have_key('grid_character')
      expect(body).not_to have_key('substitute_grid')
    end

    it 'marks the created grid item as is_substitute' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers
      sub = Substitution.last
      substitute_weapon = GridWeapon.find(sub.substitute_grid_id)
      expect(substitute_weapon.is_substitute).to be true
      expect(substitute_weapon.weapon_id).to eq(other_weapon.id)
    end

    it 'does not increment the party weapons_count' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      expect do
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      end.not_to(change { party.reload.weapons_count })
    end

    it 'auto-assigns next position when not provided' do
      # Create one substitution at position 0 (using a different weapon so the
      # dup-prevention check doesn't reject the new add)
      sw1 = create(:grid_weapon, party: party, weapon: weapon, is_substitute: true)
      create(:substitution, grid: grid_weapon, substitute_grid: sw1, position: 0)

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['position']).to eq(1)
    end

    it 'requires authentication' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json,
                                    headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects non-owner' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(
        resource_owner_id: other_user.id,
        expires_in: 30.days,
        scopes: 'public'
      )

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json,
                                    headers: {
                                      'Authorization' => "Bearer #{other_token.token}",
                                      'Content-Type' => 'application/json'
                                    }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/substitutions/:id' do
    it 'updates position' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      sub_weapon = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      substitution = create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      params = { substitution: { party_id: party.id, position: 5 } }
      put "/api/v1/substitutions/#{substitution.id}", params: params.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(substitution.reload.position).to eq(5)
    end

    it 'updates the party last_updated timestamp' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      sub_weapon = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      substitution = create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      original_updated = party.reload.last_updated

      params = { substitution: { party_id: party.id, position: 3 } }
      put "/api/v1/substitutions/#{substitution.id}", params: params.to_json, headers: headers

      expect(party.reload.last_updated).not_to eq(original_updated)
    end
  end

  describe 'DELETE /api/v1/substitutions/:id' do
    it 'destroys substitution and substitute grid item' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      sub_weapon = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      substitution = create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      expect do
        delete "/api/v1/substitutions/#{substitution.id}",
               params: { substitution: { party_id: party.id } }.to_json,
               headers: headers
      end.to change(Substitution, :count).by(-1)
                                         .and change(GridWeapon, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'does not destroy the primary grid weapon' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      sub_weapon = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      substitution = create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      delete "/api/v1/substitutions/#{substitution.id}",
             params: { substitution: { party_id: party.id } }.to_json,
             headers: headers

      expect(GridWeapon.exists?(grid_weapon.id)).to be true
    end
  end

  describe 'cross-party access' do
    let(:other_party) { create(:party, user: user) }
    let(:foreign_grid_weapon) { create(:grid_weapon, party: other_party, weapon: weapon) }
    let(:foreign_sub_weapon) { create(:grid_weapon, party: other_party, weapon: other_weapon, is_substitute: true) }
    let(:foreign_substitution) do
      create(:substitution, grid: foreign_grid_weapon, substitute_grid: foreign_sub_weapon, position: 0)
    end

    it 'rejects creating a substitution against a grid item from another party' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: foreign_grid_weapon.id,
          item_id: other_weapon.id
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects updating a substitution that belongs to another party' do
      put "/api/v1/substitutions/#{foreign_substitution.id}",
          params: { substitution: { party_id: party.id, position: 5 } }.to_json,
          headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects destroying a substitution that belongs to another party' do
      foreign_substitution # ensure created

      expect do
        delete "/api/v1/substitutions/#{foreign_substitution.id}",
               params: { substitution: { party_id: party.id } }.to_json,
               headers: headers
      end.not_to change(Substitution, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'invalid grid_type' do
    it 'returns 422 for an unrecognized grid_type' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'Object',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'duplicate substitute for the same slot' do
    let(:grid_weapon) { create(:grid_weapon, party: party, weapon: weapon) }

    let(:add_params) do
      {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id
        }
      }
    end

    it 'returns 422 on the second add of the same item' do
      post '/api/v1/substitutions', params: add_params.to_json, headers: headers
      expect(response).to have_http_status(:created)

      expect do
        post '/api/v1/substitutions', params: add_params.to_json, headers: headers
      end.not_to change(Substitution, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/already a substitute/i)
    end
  end

  describe 'invalid item_id' do
    it 'returns 422 (not 500) when item_id does not exist' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: SecureRandom.uuid
        }
      }

      expect do
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      end.not_to change(Substitution, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/unknown item_id/i)
    end
  end

  describe 'PUT with missing position' do
    it 'returns 422 when position is nil' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      sub_weapon = create(:grid_weapon, party: party, weapon: other_weapon, is_substitute: true)
      substitution = create(:substitution, grid: grid_weapon, substitute_grid: sub_weapon, position: 0)

      put "/api/v1/substitutions/#{substitution.id}",
          params: { substitution: { party_id: party.id } }.to_json,
          headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(substitution.reload.position).to eq(0)
    end
  end

  describe 'substitute uncap_level' do
    it 'matches the canonical weapon\'s max uncap' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: other_weapon.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers

      expected = if other_weapon.transcendence
                   6
                 elsif other_weapon.ulb
                   5
                 elsif other_weapon.flb
                   4
                 else
                   3
                 end
      expect(GridWeapon.find(Substitution.last.substitute_grid_id).uncap_level).to eq(expected)
    end
  end

  describe '11th substitute' do
    it 'returns 422 when the slot already has 10 substitutes' do
      grid_weapon = create(:grid_weapon, party: party, weapon: weapon)

      # 10 distinct canonical weapons (the unique-substitute index forbids
      # repeating the same canonical weapon in the same slot).
      filler_weapons = Weapon.where.not(id: weapon.id).limit(11).to_a
      raise 'need 11 distinct weapons in test seeds' if filler_weapons.length < 11

      filler_weapons.first(10).each_with_index do |w, i|
        sw = create(:grid_weapon, party: party, weapon: w, is_substitute: true)
        create(:substitution, grid: grid_weapon, substitute_grid: sw, position: i)
      end

      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridWeapon',
          grid_id: grid_weapon.id,
          item_id: filler_weapons.last.id
        }
      }

      expect do
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      end.not_to change(Substitution, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GridSummon substitution flow' do
    let(:summon) { Summon.first }
    let(:other_summon) { Summon.where.not(id: summon.id).first }
    let(:grid_summon) { create(:grid_summon, party: party, summon: summon) }

    it 'creates a substitution and a substitute grid summon' do
      params = {
        substitution: {
          party_id: party.id,
          grid_type: 'GridSummon',
          grid_id: grid_summon.id,
          item_id: other_summon.id,
          position: 0
        }
      }

      expect do
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      end.to change(Substitution, :count).by(1)
                                         .and change(GridSummon, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to have_key('grid_summon')
    end

    it 'destroys the substitute summon row on delete' do
      sub_summon = create(:grid_summon, party: party, summon: other_summon, is_substitute: true)
      substitution = create(:substitution, grid: grid_summon, substitute_grid: sub_summon, position: 0)

      expect do
        delete "/api/v1/substitutions/#{substitution.id}",
               params: { substitution: { party_id: party.id } }.to_json,
               headers: headers
      end.to change(Substitution, :count).by(-1)
                                         .and change(GridSummon, :count).by(-1)
    end
  end
end
