# frozen_string_literal: true

require 'rails_helper'

# POST /parties/:id/grid_update: who may run a batch, the response shape, and
# how the batch validates, applies and rolls back.
RSpec.describe 'POST /api/v1/parties/:id/grid_update', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  def grid_update(target, operations, request_headers = headers, options: nil)
    body = { operations: operations }
    body[:options] = options if options
    post "/api/v1/parties/#{target.id}/grid_update", params: body.to_json, headers: request_headers
  end

  def error_message
    response.parsed_body.dig('errors', 'message')
  end

  describe 'authorization' do
    let(:anonymous_party) { create(:party, user: nil) }
    let!(:weapon) { create(:grid_weapon, party: anonymous_party, position: 0) }
    let(:move) { [{ type: 'move', entity: 'weapon', id: weapon.id, position: 3 }] }

    before { anonymous_party.update_columns(edit_key: 'anon-key') }

    it 'lets an anonymous party be edited with its edit key' do
      grid_update(anonymous_party, move, { 'X-Edit-Key' => 'anon-key', 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:ok)
      expect(weapon.reload.position).to eq(3)
    end

    it 'refuses an anonymous party with the wrong edit key' do
      grid_update(anonymous_party, move, { 'X-Edit-Key' => 'wrong-key', 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
      expect(weapon.reload.position).to eq(0)
    end

    it 'refuses an anonymous party without an edit key' do
      grid_update(anonymous_party, move, { 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
      expect(weapon.reload.position).to eq(0)
    end

    it "refuses someone else's party and leaves it unchanged" do
      other_party = create(:party, user: create(:user))
      other_weapon = create(:grid_weapon, party: other_party, position: 0)

      grid_update(other_party, [{ type: 'move', entity: 'weapon', id: other_weapon.id, position: 3 }])

      expect(response).to have_http_status(:unauthorized)
      expect(other_weapon.reload.position).to eq(0)
    end

    it 'refuses a signed-out request on an owned party' do
      grid_update(party, [], { 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found for an unknown party' do
      post "/api/v1/parties/#{SecureRandom.uuid}/grid_update", params: { operations: [] }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found when addressed by shortcode' do
      post "/api/v1/parties/#{party.shortcode}/grid_update", params: { operations: [] }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "can't touch a row of another party by id" do
      other_weapon = create(:grid_weapon, party: create(:party, user: create(:user)), position: 0)

      grid_update(party, [{ type: 'move', entity: 'weapon', id: other_weapon.id, position: 3 }])

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_message).to include('Grid update failed')
      expect(other_weapon.reload.position).to eq(0)
    end
  end

  describe 'response' do
    let!(:weapon) { create(:grid_weapon, party: party, position: 0) }
    let!(:first_character) { create(:grid_character, party: party, position: 0) }
    let!(:second_character) { create(:grid_character, party: party, position: 1) }
    let!(:summon) { create(:grid_summon, party: party, position: 1) }

    it 'returns the party, the count and a change per applied operation' do
      grid_update(party, [
                    { type: 'move', entity: 'weapon', id: weapon.id, position: 3 },
                    { type: 'swap', entity: 'character', source_id: first_character.id, target_id: second_character.id },
                    { type: 'remove', entity: 'summon', id: summon.id }
                  ])

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly('party', 'operations_applied', 'changes')
      expect(body['party']['id']).to eq(party.id)
      expect(body['party']['weapons'].pluck('position')).to eq([3])
      expect(body['operations_applied']).to eq(3)
      expect(body['changes']).to eq([
                                      { 'entity' => 'weapon', 'id' => weapon.id, 'action' => 'moved', 'from' => 0, 'to' => 3 },
                                      { 'entity' => 'character', 'id' => first_character.id, 'action' => 'swapped', 'with' => second_character.id },
                                      { 'entity' => 'summon', 'id' => summon.id, 'action' => 'removed' }
                                    ])
    end

    it 'accepts an empty batch' do
      grid_update(party, [])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['operations_applied']).to eq(0)
      expect(response.parsed_body['changes']).to eq([])
    end

    it 'marks the party updated' do
      party.update_columns(last_updated: 2.days.ago)

      grid_update(party, [{ type: 'move', entity: 'weapon', id: weapon.id, position: 3 }])

      expect(party.reload.last_updated).to be_within(1.minute).of(Time.current)
    end

    it 'skips a swap whose rows are missing' do
      grid_update(party, [{ type: 'swap', entity: 'character', source_id: first_character.id, target_id: SecureRandom.uuid }])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['operations_applied']).to eq(0)
      expect(first_character.reload.position).to eq(0)
    end

    it 'skips a remove whose row is missing' do
      grid_update(party, [{ type: 'remove', entity: 'summon', id: SecureRandom.uuid }])

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['operations_applied']).to eq(0)
      expect(summon.reload).to be_present
    end

    it 'takes a position given as a string' do
      grid_update(party, [{ type: 'move', entity: 'weapon', id: weapon.id, position: '4' }])

      expect(response).to have_http_status(:ok)
      expect(weapon.reload.position).to eq(4)
    end
  end

  describe 'validation' do
    let!(:weapon) { create(:grid_weapon, party: party, position: 0) }

    it 'lists every malformed operation and applies none' do
      grid_update(party, [
                    { type: 'move', entity: 'weapon', id: weapon.id, position: 3 },
                    { type: 'move', entity: 'weapon' },
                    { type: 'swap', entity: 'character' },
                    { type: 'remove', entity: 'bullet' },
                    { type: 'flip', entity: 'summon', id: 'x' }
                  ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_message).to eq(
        'Validation failed: Operation 1: missing id, Operation 1: missing position, ' \
        'Operation 2: missing source_id, Operation 2: missing target_id, ' \
        'Operation 3: missing id, Operation 3: invalid entity type bullet, ' \
        'Operation 4: unknown operation type flip'
      )
      expect(response.parsed_body['errors']['code']).to eq('granblue_error')
      expect(weapon.reload.position).to eq(0)
    end

    it 'fails without an operations list' do
      post "/api/v1/parties/#{party.id}/grid_update", params: {}.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_message).to start_with('Grid update failed')
    end

    it 'rolls the whole batch back when a move names a missing row' do
      grid_update(party, [
                    { type: 'move', entity: 'weapon', id: weapon.id, position: 3 },
                    { type: 'move', entity: 'weapon', id: SecureRandom.uuid, position: 4 }
                  ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_message).to start_with('Grid update failed: weapon')
      expect(weapon.reload.position).to eq(0)
    end
  end

  describe 'maintain_character_sequence' do
    let!(:first_character) { create(:grid_character, party: party, position: 0) }
    let!(:second_character) { create(:grid_character, party: party, position: 2) }

    it 'closes gaps in the main character slots after the batch' do
      grid_update(party, [], options: { maintain_character_sequence: true })

      expect(response).to have_http_status(:ok)
      expect(first_character.reload.position).to eq(0)
      expect(second_character.reload.position).to eq(1)
    end

    it 'leaves gaps without the option' do
      grid_update(party, [])

      expect(second_character.reload.position).to eq(2)
    end
  end
end
