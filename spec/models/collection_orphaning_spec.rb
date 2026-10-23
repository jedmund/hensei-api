# frozen_string_literal: true

require 'rails_helper'

# Deleting a collection item unlinks the party grid items that used it and marks them
# orphaned, so the web can flag them as no longer in the collection.
RSpec.describe 'Orphaning grid items when a collection item is destroyed', type: :model do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }

  it 'orphans grid characters' do
    collection = create(:collection_character, user: user)
    grid = create(:grid_character, party: party, character: collection.character, collection_character: collection)

    collection.destroy!

    expect(grid.reload).to have_attributes(orphaned: true, collection_character_id: nil)
  end

  it 'orphans grid weapons' do
    collection = create(:collection_weapon, user: user)
    grid = create(:grid_weapon, party: party, weapon: collection.weapon, collection_weapon: collection)

    collection.destroy!

    expect(grid.reload).to have_attributes(orphaned: true, collection_weapon_id: nil)
  end

  it 'orphans grid summons' do
    collection = create(:collection_summon, user: user)
    grid = create(:grid_summon, party: party, summon: collection.summon, collection_summon: collection)

    collection.destroy!

    expect(grid.reload).to have_attributes(orphaned: true, collection_summon_id: nil)
  end

  it 'orphans grid artifacts' do
    collection = create(:collection_artifact, user: user)
    grid = create(:grid_artifact, grid_character: create(:grid_character, party: party),
                                  artifact: collection.artifact, collection_artifact: collection)

    collection.destroy!

    expect(grid.reload).to have_attributes(orphaned: true, collection_artifact_id: nil)
  end
end
