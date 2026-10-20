# frozen_string_literal: true

require 'rails_helper'

# D35: a character's fetched sources live in `sources`, not its columns.
RSpec.describe Character, 'sources' do
  let(:payload) { { 'id' => '3040999000', 'ability' => { '1' => { 'name' => 'Fire' } } } }
  let(:fetched_at) { Time.zone.parse('2026-10-01 09:00') }
  let!(:character) do
    described_class.without_skill_build do
      create(:character, wiki_raw: '{{Character}}', wiki_raw_fetched_at: fetched_at, wiki_raw_jp: '<div id="body">x</div>',
                         game_raw_en: payload)
    end
  end

  it 'stores each source as an owned row, not in the columns' do
    expect(Source.owned_by(character).pluck(:kind)).to contain_exactly('wiki_raw', 'wiki_raw_jp', 'game_raw_en')
    columns = described_class.where(id: character.id)
                             .pick(Arel.sql('wiki_raw'), Arel.sql('wiki_raw_jp'), Arel.sql('game_raw_en'))
    expect(columns).to eq([nil, nil, nil])
  end

  it 'reads them back through the attribute names' do
    record = described_class.find(character.id)

    expect(record).to have_attributes(wiki_raw: '{{Character}}', wiki_raw_fetched_at: fetched_at,
                                      wiki_raw_jp: '<div id="body">x</div>', game_raw_en: payload, game_raw_jp: nil)
  end

  it 'never loads the old columns' do
    sql = []
    callback = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?('"characters"') }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.find(character.id) }

    expect(sql.join).not_to include('"characters".*', 'wiki_raw', 'game_raw')
    expect(described_class.find(character.id).attributes.keys).not_to include('wiki_raw', 'wiki_raw_jp', 'game_raw_en')
  end

  it 'keeps an assigned value in memory until the record is saved' do
    record = described_class.find(character.id)
    record.wiki_raw = '{{Character|new=1}}'

    expect(record.wiki_raw).to eq('{{Character|new=1}}')
    expect(Source.read(character, :wiki_raw)).to eq('{{Character}}')

    record.save!
    expect(Source.read(character, :wiki_raw)).to eq('{{Character|new=1}}')
  end

  it 'keeps the fetch time for an edit and takes an assigned one' do
    character.update!(wiki_raw: '{{Character|edited=1}}')
    expect(character.reload.wiki_raw_fetched_at).to eq(fetched_at)

    character.update!(wiki_raw_fetched_at: fetched_at + 1.day)
    expect(character.reload.wiki_raw_fetched_at).to eq(fetched_at + 1.day)
  end

  it 'removes a source assigned a blank value' do
    character.update!(game_raw_en: nil)
    expect(character.reload.game_raw_en).to be_nil
    expect(Source.fetch(character, :game_raw_en)).to be_nil
  end

  it 'discards staged values on reload' do
    character.wiki_raw = 'unsaved'
    expect(character.reload.wiki_raw).to eq('{{Character}}')
  end

  it 'reads preloaded sources without a query per character' do
    records = described_class.where(id: character.id).preload(:sources).to_a
    queries = 0
    callback = ->(*) { queries += 1 }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      records.each { |record| [record.wiki_raw, record.game_raw_en, record.source_sha256(:wiki_raw_jp)] }
    end
    expect(queries).to eq(0)
  end

  it 'scopes by whether a source is stored' do
    other = described_class.without_skill_build { create(:character) }

    expect(described_class.with_source(:wiki_raw)).to include(character)
    expect(described_class.with_source(:wiki_raw)).not_to include(other)
    expect(described_class.without_source(:game_raw_jp)).to include(character, other)
  end

  it 'deletes its sources with it' do
    expect { character.destroy! }.to change(Source, :count).by(-3)
  end
end
