# frozen_string_literal: true

require 'rails_helper'

# A remix only keeps collection links into the remixer's own collection.
RSpec.describe 'Party remix collection links', type: :request do
  let(:owner) { create(:user) }
  let(:remixer) { create(:user) }

  def headers_for(user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  let(:collection_weapon) { create(:collection_weapon, user: owner) }
  let(:collection_character) { create(:collection_character, user: owner) }
  let(:collection_summon) { create(:collection_summon, user: owner) }
  let(:collection_artifact) { create(:collection_artifact, user: owner) }

  let!(:party) do
    create(:party, user: owner, visibility: 1, collection_source_user_id: owner.id).tap do |p|
      create(:grid_weapon, party: p, weapon: collection_weapon.weapon, collection_weapon: collection_weapon)
      gc = create(:grid_character, party: p, character: collection_character.character,
                                   collection_character: collection_character)
      create(:grid_summon, party: p, summon: collection_summon.summon, collection_summon: collection_summon)
      create(:grid_artifact, grid_character: gc, artifact: collection_artifact.artifact, element: 'fire',
                             collection_artifact: collection_artifact)
    end
  end

  def remix_as(user)
    post "/api/v1/parties/#{party.shortcode}/remix", headers: headers_for(user)
    expect(response).to have_http_status(:created)
    Party.find(response.parsed_body.dig('party', 'id'))
  end

  def links_of(copy)
    {
      source: copy.collection_source_user_id,
      weapons: copy.weapons.map(&:collection_weapon_id),
      characters: copy.characters.map(&:collection_character_id),
      summons: copy.summons.map(&:collection_summon_id),
      artifacts: copy.characters.filter_map(&:grid_artifact).map(&:collection_artifact_id)
    }
  end

  it "clears links when remixing another user's linked party" do
    copy = remix_as(remixer)

    expect(links_of(copy)).to eq(source: nil, weapons: [nil], characters: [nil], summons: [nil], artifacts: [nil])
    expect(response.parsed_body.dig('party', 'collection_source_user_id')).to be_nil
    # The original keeps its links.
    expect(links_of(party.reload)[:weapons]).to eq([collection_weapon.id])
  end

  it 'keeps links when remixing your own linked party' do
    copy = remix_as(owner)

    expect(links_of(copy)).to eq(source: owner.id,
                                 weapons: [collection_weapon.id],
                                 characters: [collection_character.id],
                                 summons: [collection_summon.id],
                                 artifacts: [collection_artifact.id])
  end

  it 'checks each link against its own owner' do
    # An artifact link owned by the remixer, on a party sourced from someone else.
    own_artifact = create(:collection_artifact, user: remixer)
    party.characters.first.grid_artifact.update_column(:collection_artifact_id, own_artifact.id)

    copy = remix_as(remixer)

    expect(links_of(copy)).to eq(source: nil, weapons: [nil], characters: [nil], summons: [nil],
                                 artifacts: [own_artifact.id])
  end

  it 'keeps only your own links when an artifact on your party comes from someone else' do
    foreign_artifact = create(:collection_artifact, user: remixer)
    party.characters.first.grid_artifact.update_column(:collection_artifact_id, foreign_artifact.id)

    copy = remix_as(owner)

    expect(links_of(copy)).to eq(source: owner.id,
                                 weapons: [collection_weapon.id],
                                 characters: [collection_character.id],
                                 summons: [collection_summon.id],
                                 artifacts: [nil])
  end
end
