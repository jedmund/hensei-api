# frozen_string_literal: true

require 'rails_helper'

# Sentry HENSEI-API-D, F and 7: check_updates (preview_updates) and import looked up
# each item's catalog row and the user's copy one query at a time. Both now preload
# them, so the lookups don't grow with the list.
RSpec.describe 'Collection import lookups', type: :service do
  let(:user) { create(:user) }

  # SELECTs against the given tables while the block runs
  def lookup_queries(*tables)
    queries = []
    sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      sql = payload[:sql]
      queries << sql if sql.start_with?('SELECT') && tables.any? { |table| sql.include?("FROM \"#{table}\"") }
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def game_item(game_id, granblue_id, evolution: 4)
    { 'param' => { 'id' => game_id, 'image_id' => granblue_id, 'evolution' => evolution, 'phase' => 0 },
      'master' => { 'id' => granblue_id } }
  end

  shared_examples 'a batched lookup' do |tables|
    it 'runs the same lookups for 2 items as for 6' do
      counts = [2, 6].map do |n|
        data = { 'list' => items(n) }
        lookup_queries(*tables) { run(data) }.size
      end

      expect(counts.first).to eq(counts.last)
    end
  end

  describe CharacterImportService do
    def items(count)
      Array.new(count) do |i|
        character = create(:character)
        create(:collection_character, user: user, character: character, uncap_level: 3)
        game_item(i + 1, character.granblue_id)
      end
    end

    context 'when previewing updates' do
      def run(data) = described_class.new(user, data).preview_updates

      it_behaves_like 'a batched lookup', %w[characters collection_characters]
    end

    context 'when importing' do
      def run(data) = described_class.new(user, data, update_existing: true).import

      it_behaves_like 'a batched lookup', %w[characters collection_characters]
    end

    it 'skips a character listed twice instead of creating it twice' do
      character = create(:character)
      list = [game_item(1, character.granblue_id), game_item(2, character.granblue_id)]

      result = described_class.new(user, { 'list' => list }).import

      expect(result.created.size).to eq(1)
      expect(result.skipped.size).to eq(1)
      expect(result.errors).to be_empty
    end

    it 'matches a style-shifted granblue_id to the base character' do
      base = create(:character, style_swap: false)
      create(:character, granblue_id: base.granblue_id, style_swap: true)

      result = described_class.new(user, { 'list' => [game_item(1, base.granblue_id)] }).import

      expect(result.created.map(&:character_id)).to eq([base.id])
    end
  end

  describe SummonImportService do
    def items(count)
      Array.new(count) do |i|
        summon = create(:summon)
        game_id = (count * 100) + i # each run its own game ids
        create(:collection_summon, user: user, summon: summon, game_id: game_id.to_s, uncap_level: 3)
        game_item(game_id, summon.granblue_id)
      end
    end

    context 'when previewing updates' do
      def run(data) = described_class.new(user, data).preview_updates

      it_behaves_like 'a batched lookup', %w[summons collection_summons]
    end

    context 'when importing' do
      def run(data) = described_class.new(user, data, update_existing: true).import

      it_behaves_like 'a batched lookup', %w[summons collection_summons]
    end

    it 'finds a Forged Arcarum summon by its mapped id' do
      justice = create(:summon, granblue_id: '2040236000')

      result = described_class.new(user, { 'list' => [game_item(1, '2040313000')] }).import

      expect(result.created.map(&:summon_id)).to eq([justice.id])
    end
  end

  describe WeaponImportService do
    def items(count)
      Array.new(count) do |i|
        weapon = create(:weapon)
        game_id = (count * 100) + i # each run its own game ids
        create(:collection_weapon, user: user, weapon: weapon, game_id: game_id.to_s, uncap_level: 3)
        game_item(game_id, weapon.granblue_id)
      end
    end

    context 'when previewing updates' do
      def run(data) = described_class.new(user, data).preview_updates

      it_behaves_like 'a batched lookup', %w[weapons collection_weapons]
    end

    context 'when importing' do
      def run(data) = described_class.new(user, data, update_existing: true).import

      it_behaves_like 'a batched lookup', %w[weapons collection_weapons]
    end

    it 'updates a copy listed twice instead of creating it twice' do
      weapon = create(:weapon)
      list = [game_item(1, weapon.granblue_id, evolution: 3), game_item(1, weapon.granblue_id, evolution: 4)]

      result = described_class.new(user, { 'list' => list }, update_existing: true).import

      expect(result.created.size).to eq(1)
      expect(result.updated.size).to eq(1)
      expect(user.collection_weapons.sole.uncap_level).to eq(4)
    end
  end
end
