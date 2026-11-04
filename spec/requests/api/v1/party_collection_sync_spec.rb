# frozen_string_literal: true

require 'rails_helper'

# Who may sync a party's linked grid items (POST /parties/:id/sync_all) or
# drop its collection links (POST /parties/:id/unlink_collection), and what
# each leaves behind. Access to the linked collections themselves is in
# collection_sync_access_spec.rb.
RSpec.describe 'Party collection sync', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:anonymous_party) { create(:party, user: nil) }

  before { anonymous_party.update_columns(edit_key: 'anon-key') }

  def link_weapon(target, owner: user)
    collection_weapon = create(:collection_weapon, user: owner, uncap_level: 5)
    create(:grid_weapon, party: target, weapon: collection_weapon.weapon, uncap_level: 3,
                         collection_weapon: collection_weapon)
  end

  describe 'POST /api/v1/parties/:id/sync_all' do
    it 'syncs the linked rows and returns the party with counts' do
      grid_weapon = link_weapon(party)

      post "/api/v1/parties/#{party.id}/sync_all", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to contain_exactly('party', 'synced', 'skipped')
      expect(body['party']['id']).to eq(party.id)
      expect(body['synced']).to eq('characters' => 0, 'weapons' => 1, 'summons' => 0, 'artifacts' => 0)
      expect(body['skipped']).to eq('characters' => 0, 'weapons' => 0, 'summons' => 0, 'artifacts' => 0)
      expect(grid_weapon.reload.uncap_level).to eq(5)
    end

    it "refuses someone else's party" do
      other_party = create(:party, user: create(:user))
      grid_weapon = link_weapon(other_party, owner: other_party.user)

      post "/api/v1/parties/#{other_party.id}/sync_all", headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(grid_weapon.reload.uncap_level).to eq(3)
    end

    it 'syncs an anonymous party with its edit key' do
      post "/api/v1/parties/#{anonymous_party.id}/sync_all",
           headers: { 'X-Edit-Key' => 'anon-key', 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:ok)
    end

    it 'refuses an anonymous party with the wrong edit key' do
      post "/api/v1/parties/#{anonymous_party.id}/sync_all",
           headers: { 'X-Edit-Key' => 'wrong', 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found for an unknown party' do
      post "/api/v1/parties/#{SecureRandom.uuid}/sync_all", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/parties/:id/unlink_collection' do
    it 'drops the links and the collection source, keeping the rows' do
      grid_weapon = link_weapon(party)
      grid_weapon.update_columns(orphaned: true)
      party.update_columns(collection_source_user_id: user.id)

      post "/api/v1/parties/#{party.id}/unlink_collection", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq(['party'])
      expect(response.parsed_body['party']['id']).to eq(party.id)
      grid_weapon.reload
      expect(grid_weapon.collection_weapon_id).to be_nil
      expect(grid_weapon.orphaned).to be(false)
      expect(party.reload.collection_source_user_id).to be_nil
    end

    it "refuses someone else's party" do
      other_party = create(:party, user: create(:user))
      grid_weapon = link_weapon(other_party, owner: other_party.user)

      post "/api/v1/parties/#{other_party.id}/unlink_collection", headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(grid_weapon.reload.collection_weapon_id).to be_present
    end

    # Unlinking is for the owner's account only; an edit key doesn't unlock it.
    it 'refuses an anonymous party even with its edit key' do
      post "/api/v1/parties/#{anonymous_party.id}/unlink_collection",
           headers: { 'X-Edit-Key' => 'anon-key', 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a signed-out request' do
      post "/api/v1/parties/#{party.id}/unlink_collection", headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found for an unknown party' do
      post "/api/v1/parties/#{SecureRandom.uuid}/unlink_collection", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
