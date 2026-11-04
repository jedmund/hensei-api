# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyMigration do
  let(:user) { create(:user) }
  let!(:anon_party) { create(:party, user: nil) }

  before { anon_party.update_columns(edit_key: 'key1') }

  describe '#too_many?' do
    it 'allows up to 100 entries' do
      entries = Array.new(100) { { shortcode: 'X', edit_key: 'k' } }

      expect(described_class.new(user, entries).too_many?).to be false
      expect(described_class.new(user, entries + [{ shortcode: 'Y' }]).too_many?).to be true
    end
  end

  describe '#claim!' do
    it 'moves a party with its key to the user and clears the key' do
      result = described_class.new(user, [{ shortcode: anon_party.shortcode, edit_key: 'key1' }]).claim!

      expect(result).to eq(results: [{ shortcode: anon_party.shortcode, status: 'migrated' }], migrated_count: 1)
      expect(anon_party.reload).to have_attributes(user_id: user.id, edit_key: nil)
    end

    it 'reports a party named twice as claimed the second time' do
      entries = [{ shortcode: anon_party.shortcode, edit_key: 'key1' }, { shortcode: anon_party.id, edit_key: 'key1' }]

      result = described_class.new(user, entries).claim!

      expect(result[:results].pluck(:status)).to eq(%w[migrated already_claimed])
      expect(result[:migrated_count]).to eq(1)
    end

    it "uses the user's deposited keys when given no entries" do
      user.user_edit_keys.create!(shortcode: anon_party.shortcode, edit_key: 'key1')

      described_class.new(user, nil).claim!

      expect(anon_party.reload.user_id).to eq(user.id)
      expect(user.user_edit_keys.count).to eq(0)
    end
  end

  describe '#preview' do
    it 'returns the party for ready and visible claimed entries, nil otherwise' do
      private_party = create(:party, user: create(:user), visibility: 3)
      entries = [
        { shortcode: anon_party.shortcode, edit_key: 'key1' },
        { shortcode: private_party.shortcode, edit_key: 'x' },
        { shortcode: 'NOPE99', edit_key: 'x' }
      ]

      rows = described_class.new(user, entries).preview

      expect(rows).to eq([
                           { party: anon_party, status: 'ready' },
                           { party: nil, status: 'not_found' },
                           { party: nil, status: 'not_found' }
                         ])
      expect(anon_party.reload.user_id).to be_nil
    end
  end
end
