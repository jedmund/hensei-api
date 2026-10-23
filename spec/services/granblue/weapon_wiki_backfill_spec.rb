# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::WeaponWikiBackfill do
  let(:fixtures) { Rails.root.join('spec/fixtures/wiki/cargo') }
  let(:sample_body) { fixtures.join('weapons_cargoquery_sample.json').read }
  let(:sample_rows) { described_class.parse_response(sample_body) }
  let(:io) { StringIO.new }
  let(:requests) { [] }
  # Answers like gbf.wiki would: the sample's rows for the ids asked about.
  let(:fetcher) do
    lambda do |ids|
      requests << ids
      { 'cargoquery' => sample_rows.select { |row| ids.include?(row['id']) }.map { |row| { 'title' => row } } }.to_json
    end
  end

  before { allow(Granblue::WikiThrottle).to receive(:wait) }

  def backfill(**)
    described_class.new(fetcher: fetcher, io: io, **).call
  end

  def blank_weapon(granblue_id, name, **attributes)
    create(:weapon, granblue_id: granblue_id, name_en: name, wiki_en: '', release_date: nil, flb_date: nil,
                    ulb_date: nil, **attributes)
  end

  describe 'the Cargo fields' do
    it 'names real columns of the gbf.wiki weapons table' do
      columns = JSON.parse(fixtures.join('weapons_cargofields.json').read).fetch('cargofields').keys
      fields = described_class::FIELDS.split(',').map { |field| field.split('=').first }

      expect(fields - ['_pageName']).to all(be_in(columns))
    end
  end

  describe '.parse_response' do
    it 'returns each row with the page name and the dates Cargo spells with spaces' do
      row = sample_rows.find { |r| r['id'] == '1020000400' }

      expect(sample_rows.size).to eq(5)
      expect(row).to include('page' => 'Thunder Rapier', 'release date' => '2014-03-10', '4star date' => '')
    end

    it 'raises on a Cargo error' do
      body = { error: { code: 'internal_api_error' } }.to_json
      expect { described_class.parse_response(body) }.to raise_error(described_class::FetchError, /Cargo error/)
    end

    it 'raises on a body that is not JSON' do
      expect { described_class.parse_response('<html>') }.to raise_error(described_class::FetchError, /not JSON/)
    end
  end

  describe '.query_params' do
    it 'asks for the ids with an IN clause' do
      params = described_class.query_params(%w[1020000400 1030005900])

      expect(params).to include(action: 'cargoquery', tables: 'weapons', where: 'id IN ("1020000400","1030005900")',
                                limit: 500)
    end
  end

  describe '#call' do
    let!(:rapier) { blank_weapon('1020000400', 'Thunder Rapier', rarity: 1) }
    let!(:flag) { blank_weapon('1030005900', 'White Flag', rarity: 2) }

    it 'proposes the page name and release date in a dry run without writing' do
      result = backfill

      expect(result.changes.map { |c| [c.weapon.granblue_id, c.field, c.new] }).to contain_exactly(
        ['1020000400', 'wiki_en', 'Thunder Rapier'], ['1020000400', 'release_date', Date.new(2014, 3, 10)],
        ['1030005900', 'wiki_en', 'White Flag'], ['1030005900', 'release_date', Date.new(2016, 11, 18)]
      )
      expect(rapier.reload.wiki_en).to eq('')
      expect(rapier.release_date).to be_nil
      expect(io.string).to include('Dry run', '1020000400 Thunder Rapier: wiki_en: nil → "Thunder Rapier"')
    end

    it 'writes the blank fields with write: true' do
      backfill(write: true)

      expect(rapier.reload).to have_attributes(wiki_en: 'Thunder Rapier', release_date: Date.new(2014, 3, 10),
                                               flb_date: nil, ulb_date: nil)
      expect(flag.reload.wiki_en).to eq('White Flag')
    end

    it 'never overwrites a value that is already set' do
      rapier.update_columns(wiki_en: 'Our Rapier Page')
      flag.update_columns(release_date: Date.new(2020, 1, 1))

      backfill(write: true)

      expect(rapier.reload).to have_attributes(wiki_en: 'Our Rapier Page', release_date: Date.new(2014, 3, 10))
      expect(flag.reload).to have_attributes(wiki_en: 'White Flag', release_date: Date.new(2020, 1, 1))
    end

    it 'fills FLB and ULB dates only where ours are blank' do
      rows = sample_rows.map do |row|
        row['id'] == '1030005900' ? row.merge('4star date' => '2019-03-10', '4star date__precision' => '1') : row
      end
      allow(described_class).to receive(:parse_response).and_return(rows)

      backfill(write: true)

      expect(flag.reload.flb_date).to eq(Date.new(2019, 3, 10))
    end

    it 'skips a date coarser than a day and says so' do
      rows = sample_rows.map do |row|
        row['id'] == '1030005900' ? row.merge('release date' => '2016-11-01', 'release date__precision' => '2') : row
      end
      allow(described_class).to receive(:parse_response).and_return(rows)

      result = backfill

      expect(result.changes.map { |c| [c.weapon.granblue_id, c.field] }).not_to include(%w[1030005900 release_date])
      expect(io.string).to include('1030005900 White Flag: release date "2016-11-01" is not a full date')
    end

    it 'lists weapons the wiki does not have, matching by id only' do
      missing = blank_weapon('1099999900', 'Thunder Rapier')

      result = backfill

      expect(result.unmatched).to eq([missing])
      expect(result.changes.map(&:weapon)).not_to include(missing)
      expect(io.string).to include("Not on gbf.wiki Cargo (by id): 1\n  1099999900 Thunder Rapier")
    end

    it 'leaves weapons that have a page name and a release date out of scope' do
      create(:weapon, granblue_id: '1030006000', wiki_en: 'Aquablade', release_date: Date.new(2017, 1, 31))

      expect(backfill.scope_count).to eq(2)
      expect(requests.flatten).not_to include('1030006000')
    end

    it 'narrows the scope by ids and rarities' do
      expect(backfill(ids: ['1030005900']).changes.map(&:weapon).uniq).to eq([flag])
      expect(backfill(rarities: [1]).changes.map(&:weapon).uniq).to eq([rapier])
    end

    it 'queries in chunks, waiting before each request' do
      blank_weapon('1030006000', 'Aquablade')

      backfill(chunk_size: 2)

      expect(requests).to eq([%w[1020000400 1030005900], ['1030006000']])
      expect(Granblue::WikiThrottle).to have_received(:wait).with(2.0).twice
    end

    it 'stores the rows once and parses the stored copy on the next run' do
      backfill
      requests.clear

      result = backfill(write: true)

      expect(requests).to be_empty
      expect(result.changes.size).to eq(4)
      stored = Source.read(nil, 'wiki_cargo', key: 'weapons')
      expect(stored['queried']).to eq(%w[1020000400 1030005900])
      expect(stored['rows']['1020000400'].first['page']).to eq('Thunder Rapier')
    end

    it 'remembers ids the wiki lacks, and refresh: true asks again' do
      blank_weapon('1099999900', 'Nowhere')
      backfill
      requests.clear

      backfill
      expect(requests).to be_empty

      backfill(refresh: true)
      expect(requests.flatten).to contain_exactly('1020000400', '1030005900', '1099999900')
    end

    it 'is idempotent: a second write run finds nothing to change' do
      backfill(write: true)

      result = backfill(write: true)

      expect(result.scope_count).to eq(0)
      expect(result.changes).to be_empty
    end

    it 'makes no request offline and lists the ids it has no rows for' do
      result = backfill(offline: true)

      expect(requests).to be_empty
      expect(result.not_fetched).to eq(%w[1020000400 1030005900])
      expect(result.changes).to be_empty
      expect(io.string).to include('Not fetched (offline): 2 ids')
    end

    it 'skips an id that several wiki pages claim' do
      rows = sample_rows + [sample_rows.find { |row| row['id'] == '1030005900' }.merge('page' => 'White Flag (Other)')]
      allow(described_class).to receive(:parse_response).and_return(rows)

      result = backfill

      expect(result.changes.map(&:weapon)).not_to include(flag)
      expect(io.string).to include('several wiki pages share this id')
    end
  end
end
