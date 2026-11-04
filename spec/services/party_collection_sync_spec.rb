# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyCollectionSync do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }

  def linked_weapon(position)
    collection_weapon = create(:collection_weapon, user: user, uncap_level: 5)
    create(:grid_weapon, party: party, weapon: collection_weapon.weapon, position: position, uncap_level: 3,
                         collection_weapon: collection_weapon)
  end

  describe '#sync_all!' do
    it 'syncs the rows the block accepts and counts the rest as skipped' do
      synced = linked_weapon(0)
      refused = linked_weapon(1)

      result = described_class.new(party).sync_all! { |item| item != refused.collection_weapon }

      expect(result.synced).to eq(characters: 0, weapons: 1, summons: 0, artifacts: 0)
      expect(result.skipped).to eq(characters: 0, weapons: 1, summons: 0, artifacts: 0)
      expect(synced.reload.uncap_level).to eq(5)
      expect(refused.reload.uncap_level).to eq(3)
    end

    it 'leaves unlinked rows out of the counts' do
      create(:grid_weapon, party: party, position: 0)

      result = described_class.new(party).sync_all! { true }

      expect(result.synced.values.sum + result.skipped.values.sum).to eq(0)
    end
  end

  describe '#unlink!' do
    it 'clears the links, the orphaned flags and the collection source, keeping the rows' do
      weapon = linked_weapon(0)
      weapon.update_columns(orphaned: true)
      collection_character = create(:collection_character, user: user)
      character = create(:grid_character, party: party, character: collection_character.character,
                                          collection_character: collection_character)
      party.update_columns(collection_source_user_id: user.id)

      described_class.new(party).unlink!

      expect(weapon.reload).to have_attributes(collection_weapon_id: nil, orphaned: false)
      expect(character.reload.collection_character_id).to be_nil
      expect(party.reload.collection_source_user_id).to be_nil
    end
  end
end
