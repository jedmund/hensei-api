# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotesSync do
  let(:party) { create(:party) }
  let(:weapon_series) { create(:weapon_series, extra: false) }
  let(:canonical_weapon) { create(:weapon, limit: false, weapon_series: weapon_series) }
  let(:other_weapon) { create(:weapon, limit: false, weapon_series: weapon_series) }

  let(:summon) { Summon.find_by!(granblue_id: '2040034000') }
  let(:other_summon) { Summon.find_by!(granblue_id: '2040003000') }

  let(:doc_a) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'A' }] }] } }
  let(:doc_b) { { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'B' }] }] } }

  describe '.siblings' do
    it 'returns other grid weapons in the same party with the same canonical weapon' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0)
      b = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1)
      unrelated = create(:grid_weapon, party: party, weapon: other_weapon, position: 2)

      result = described_class.siblings(a).to_a
      expect(result).to contain_exactly(b)
      expect(result).not_to include(unrelated)
      expect(result).not_to include(a)
    end

    it 'returns nil for unsupported types (e.g. GridCharacter)' do
      character = Character.find_by!(granblue_id: '3040087000')
      grid_char = create(:grid_character, party: party, character: character, position: 0,
                                          uncap_level: 3, transcendence_step: 0)
      expect(described_class.siblings(grid_char)).to be_nil
    end
  end

  describe '.enable_sync!' do
    it 'flips the flag on every sibling and copies the source description' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0, description: doc_a)
      b = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1, description: doc_b)

      described_class.enable_sync!(a)

      expect(a.reload.notes_synced).to be true
      expect(b.reload.notes_synced).to be true
      expect(b.description).to eq(doc_a)
    end

    it 'is a no-op for unsyncable items' do
      character = Character.find_by!(granblue_id: '3040087000')
      grid_char = create(:grid_character, party: party, character: character, position: 0,
                                          uncap_level: 3, transcendence_step: 0)
      expect(described_class.enable_sync!(grid_char)).to be false
    end
  end

  describe '.disable_sync!' do
    it 'turns the flag off on every sibling but leaves descriptions alone' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0,
                               description: doc_a, notes_synced: true)
      b = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1,
                               description: doc_a, notes_synced: true)

      described_class.disable_sync!(a)

      expect(a.reload.notes_synced).to be false
      expect(b.reload.notes_synced).to be false
      expect(a.description).to eq(doc_a)
      expect(b.description).to eq(doc_a)
    end
  end

  describe '.propagate_description!' do
    it 'mirrors the source description onto every sibling when synced' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0,
                               description: doc_a, notes_synced: true)
      b = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1,
                               description: doc_b, notes_synced: true)

      described_class.propagate_description!(a)

      expect(b.reload.description).to eq(doc_a)
    end

    it 'is a no-op when the item is not synced' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0,
                               description: doc_a, notes_synced: false)
      b = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1,
                               description: doc_b, notes_synced: false)

      described_class.propagate_description!(a)

      expect(b.reload.description).to eq(doc_b)
    end
  end

  describe '.adopt_for_new_item!' do
    it 'pulls the new item into an existing sync group' do
      leader = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0,
                                    description: doc_a, notes_synced: true)
      newcomer = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1,
                                      description: doc_b, notes_synced: false)

      described_class.adopt_for_new_item!(newcomer)

      expect(newcomer.reload.notes_synced).to be true
      expect(newcomer.description).to eq(doc_a)
      expect(leader.reload.description).to eq(doc_a)
    end

    it 'is a no-op when no sibling is already synced' do
      a = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 0,
                               description: doc_a, notes_synced: false)
      newcomer = create(:grid_weapon, party: party, weapon: canonical_weapon, position: 1,
                                      description: doc_b, notes_synced: false)

      described_class.adopt_for_new_item!(newcomer)

      expect(newcomer.reload.notes_synced).to be false
      expect(newcomer.description).to eq(doc_b)
      expect(a.reload.description).to eq(doc_a)
    end
  end

  describe '.propagate_description! across summons' do
    it 'mirrors descriptions across duplicate summons in the same party' do
      summon.update!(transcendence: true, ulb: true, flb: true)
      a = create(:grid_summon, party: party, summon: summon, position: 0, uncap_level: 3,
                               description: doc_a, notes_synced: true)
      b = create(:grid_summon, party: party, summon: summon, position: 1, uncap_level: 3,
                               description: doc_b, notes_synced: true)
      unrelated = create(:grid_summon, party: party, summon: other_summon, position: 2,
                                       uncap_level: 3, description: doc_b)

      described_class.propagate_description!(a)

      expect(b.reload.description).to eq(doc_a)
      expect(unrelated.reload.description).to eq(doc_b)
    end
  end
end
