# frozen_string_literal: true

require 'rails_helper'

# Grid rows must be authorized against the party they actually belong to,
# not a party id supplied in the request.
RSpec.describe 'Grid item cross-party authorization', type: :request do
  let(:owner) { create(:user) }
  let(:attacker) { create(:user) }
  let(:owner_party) { create(:party, user: owner) }
  let(:attacker_party) { create(:party, user: attacker) }

  def headers_for(user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  let(:attacker_headers) { headers_for(attacker) }
  let(:owner_headers) { headers_for(owner) }

  shared_examples 'a party-scoped grid resource' do |path:, param_key:|
    it 'rejects update when another party id is supplied' do
      put "/api/v1/#{path}/#{row.id}",
          params: { param_key => { party_id: attacker_party.id, uncap_level: 1 } }.to_json,
          headers: attacker_headers
      expect(response.status).to be_in([401, 404])
      expect(row.reload.uncap_level).to eq(3)
      expect(row.party_id).to eq(owner_party.id)
    end

    it 'rejects update without a party id' do
      put "/api/v1/#{path}/#{row.id}",
          params: { param_key => { uncap_level: 1 } }.to_json,
          headers: attacker_headers
      expect(response).to have_http_status(:unauthorized)
      expect(row.reload.uncap_level).to eq(3)
    end

    it 'rejects destroy when another party id is supplied' do
      delete "/api/v1/#{path}/#{row.id}?party_id=#{attacker_party.id}", headers: attacker_headers
      expect(response.status).to be_in([401, 404])
      expect(row.class.exists?(row.id)).to be(true)
    end

    it 'rejects update_uncap when another party id is supplied' do
      post "/api/v1/#{path}/update_uncap",
           params: { param_key => { id: row.id, party_id: attacker_party.id, uncap_level: 1 } }.to_json,
           headers: attacker_headers
      expect(response.status).to be_in([401, 404])
      expect(row.reload.uncap_level).to eq(3)
    end

    it 'rejects update_position through another party route' do
      put "/api/v1/parties/#{attacker_party.id}/#{path}/#{row.id}/position",
          params: { position: 2 }.to_json,
          headers: attacker_headers
      expect(response.status).to be_in([401, 404])
      expect(row.reload.party_id).to eq(owner_party.id)
    end

    it 'lets the owner update without a party id' do
      put "/api/v1/#{path}/#{row.id}",
          params: { param_key => { uncap_level: 2 } }.to_json,
          headers: owner_headers
      expect(response).to have_http_status(:ok)
      expect(row.reload.uncap_level).to eq(2)
    end

    it 'does not move the row when the owner supplies a different party id in update' do
      other_owner_party = create(:party, user: owner)
      put "/api/v1/#{path}/#{row.id}",
          params: { param_key => { party_id: other_owner_party.id, uncap_level: 2 } }.to_json,
          headers: owner_headers
      expect(row.reload.party_id).to eq(owner_party.id)
    end

    it 'lets the owner destroy' do
      delete "/api/v1/#{path}/#{row.id}", headers: owner_headers
      expect(response).to have_http_status(:ok)
      expect(row.class.exists?(row.id)).to be(false)
    end
  end

  describe 'grid weapons' do
    let!(:row) { create(:grid_weapon, party: owner_party, position: 0) }

    it_behaves_like 'a party-scoped grid resource', path: 'grid_weapons', param_key: :weapon

    it 'rejects duplicate when another party id is supplied' do
      expect do
        post "/api/v1/grid_weapons/#{row.id}/duplicate?party_id=#{attacker_party.id}",
             params: { position: 3 }.to_json,
             headers: attacker_headers
      end.not_to change(GridWeapon, :count)
    end

    it "does not sync into another user's collection item" do
      victim_item = create(:collection_weapon, user: owner, weapon: row.weapon, uncap_level: 3)
      attacker_party.update!(collection_source_user_id: attacker.id)
      own_row = create(:grid_weapon, party: attacker_party, weapon: row.weapon, position: 1, uncap_level: 1)
      own_row.update_column(:collection_weapon_id, victim_item.id)

      post "/api/v1/grid_weapons/#{own_row.id}/sync_to_collection", headers: attacker_headers
      expect(response).to have_http_status(:unauthorized)
      expect(victim_item.reload.uncap_level).to eq(3)
    end

    it "rejects linking another user's private collection item on update" do
      owner.update!(collection_privacy: :private_collection)
      victim_item = create(:collection_weapon, user: owner, weapon: row.weapon)
      own_row = create(:grid_weapon, party: attacker_party, weapon: row.weapon, position: 1)

      put "/api/v1/grid_weapons/#{own_row.id}",
          params: { weapon: { collection_weapon_id: victim_item.id } }.to_json,
          headers: attacker_headers
      expect(response).to have_http_status(:forbidden)
      expect(own_row.reload.collection_weapon_id).to be_nil
    end
  end

  describe 'grid characters' do
    let!(:row) { create(:grid_character, party: owner_party, position: 0) }

    it_behaves_like 'a party-scoped grid resource', path: 'grid_characters', param_key: :character
  end

  describe 'grid summons' do
    let!(:row) { create(:grid_summon, party: owner_party, position: 1) }

    it_behaves_like 'a party-scoped grid resource', path: 'grid_summons', param_key: :summon
  end
end
