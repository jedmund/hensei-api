# frozen_string_literal: true

require 'rails_helper'

# Pulling data from a linked collection item follows the same access rule as
# linking it: the item must be the viewer's own, or its owner's collection
# must be visible to them.
RSpec.describe 'Collection sync access', type: :request do
  let(:user) { create(:user) }
  let(:owner) { create(:user, collection_privacy: :private_collection) }
  let(:party) { create(:party, user: user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:collection_weapon) { create(:collection_weapon, user: owner, uncap_level: 5) }
  let(:collection_character) { create(:collection_character, user: owner, uncap_level: 5) }
  let(:collection_summon) { create(:collection_summon, user: owner, uncap_level: 5) }
  let(:collection_artifact) { create(:collection_artifact, user: owner, level: 5) }

  let(:grid_weapon) do
    create(:grid_weapon, party: party, weapon: collection_weapon.weapon, uncap_level: 3,
                         collection_weapon: collection_weapon)
  end
  let(:grid_character) do
    create(:grid_character, party: party, character: collection_character.character, uncap_level: 3,
                            collection_character: collection_character)
  end
  let(:grid_summon) do
    create(:grid_summon, party: party, summon: collection_summon.summon, uncap_level: 3,
                         collection_summon: collection_summon)
  end
  let(:grid_artifact) do
    create(:grid_artifact, grid_character: grid_character, artifact: collection_artifact.artifact, level: 1,
                           element: 'fire', collection_artifact: collection_artifact)
  end

  def expect_forbidden_without_item_data
    expect(response).to have_http_status(:forbidden)
    body = response.parsed_body
    expect(body.keys).not_to include('grid_weapon', 'grid_character', 'grid_summon', 'grid_artifact')
    expect(response.body).not_to include(owner.username)
  end

  describe 'POST /grid_weapons/:id/sync' do
    it 'refuses a link into a collection the user cannot see' do
      post "/api/v1/grid_weapons/#{grid_weapon.id}/sync", headers: headers

      expect_forbidden_without_item_data
      expect(grid_weapon.reload.uncap_level).to eq(3)
    end

    it 'syncs when the owner shares their collection with everyone' do
      owner.update!(collection_privacy: :everyone)

      post "/api/v1/grid_weapons/#{grid_weapon.id}/sync", headers: headers

      expect(response).to have_http_status(:ok)
      expect(grid_weapon.reload.uncap_level).to eq(5)
    end
  end

  describe 'POST /grid_characters/:id/sync' do
    it 'refuses a link into a collection the user cannot see' do
      post "/api/v1/grid_characters/#{grid_character.id}/sync", headers: headers

      expect_forbidden_without_item_data
      expect(grid_character.reload.uncap_level).to eq(3)
    end

    it 'syncs from a crewmate whose collection is crew-only' do
      owner.update!(collection_privacy: :crew_only)
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: owner)
      create(:crew_membership, crew: crew, user: user)

      post "/api/v1/grid_characters/#{grid_character.id}/sync", headers: headers

      expect(response).to have_http_status(:ok)
      expect(grid_character.reload.uncap_level).to eq(5)
    end
  end

  describe 'POST /grid_summons/:id/sync' do
    it 'refuses a link into a collection the user cannot see' do
      post "/api/v1/grid_summons/#{grid_summon.id}/sync", headers: headers

      expect_forbidden_without_item_data
      expect(grid_summon.reload.uncap_level).to eq(3)
    end
  end

  describe 'POST /grid_artifacts/:id/sync' do
    it 'refuses a link into a collection the user cannot see' do
      post "/api/v1/grid_artifacts/#{grid_artifact.id}/sync", headers: headers

      expect_forbidden_without_item_data
      expect(grid_artifact.reload.level).to eq(1)
    end
  end

  describe 'POST /parties/:id/sync_all' do
    it 'skips and counts items the user cannot see, and syncs their own' do
      own_weapon = create(:collection_weapon, user: user, uncap_level: 5)
      own_grid_weapon = create(:grid_weapon, party: party, weapon: own_weapon.weapon, position: 1,
                                             uncap_level: 3, collection_weapon: own_weapon)
      grid_weapon
      grid_summon
      grid_artifact

      post "/api/v1/parties/#{party.id}/sync_all", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['synced']).to eq('characters' => 0, 'weapons' => 1, 'summons' => 0, 'artifacts' => 0)
      expect(body['skipped']).to eq('characters' => 1, 'weapons' => 1, 'summons' => 1, 'artifacts' => 1)

      expect(own_grid_weapon.reload.uncap_level).to eq(5)
      expect(grid_weapon.reload.uncap_level).to eq(3)
      expect(grid_character.reload.uncap_level).to eq(3)
      expect(grid_summon.reload.uncap_level).to eq(3)
      expect(grid_artifact.reload.level).to eq(1)
    end
  end
end
