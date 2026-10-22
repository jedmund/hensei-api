# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusList do
  before { described_class.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua'))) }

  def resolve(name) = described_class.resolve(name)&.to_h&.merge(variant: described_class.resolve(name)&.variant)

  it 'resolves a numbered entry to its base, with the exact display id and the variant' do
    expect(resolve('Accuracy Lowered 2')).to include(entry: 'Accuracy Lowered 2', base: 'Accuracy Lowered', category: 'debuff',
                                                     status_id: '1032_42', base_status_id: '1032_4', variant: 2)
  end

  it 'follows aliases and chains of links' do
    expect(resolve('DEF Down 4')).to include(base: 'DEF Lowered', status_id: '1020_14', variant: 4, page: 'DEF Down')
    expect(resolve('Other Self')).to include(base: 'Dodge All', status_id: '1019', variant: nil)
    expect(resolve('5% Cut')).to include(base: 'DMG Cut', status_id: '1019_0_5', base_status_id: nil)
  end

  it 'keeps Blind and Accuracy Lowered apart, and finds a status by its wiki page title' do
    expect(resolve('Blind')).to include(entry: 'Blinded', base: 'Blinded', status_id: '1032')
    expect(resolve('blinded')[:base]).to eq('Blinded')
    expect(resolve('Accuracy Lowered')[:base]).to eq('Accuracy Lowered')
  end

  it 'maps the effects table to instant effects and a field comment to field' do
    expect(resolve('Charge Boost')).to include(base: 'Charge Bar', category: 'special', status_id: '1061',
                                               detail: 'Instantly boosts Charge Bar by %a%')
    expect(resolve('Sun-Touched Paradise')[:category]).to eq('field')
  end

  it 'gives the base entry its own description' do
    expect(resolve('5% DMG Cut')).to include(detail: 'Taking 5% less DMG', base_detail: 'Taking less DMG')
  end

  it "knows the wiki's own spellings: entries, aliases and page titles" do
    expect(described_class.current.vocabulary).to include('blinded', 'blind', 'def down 4', 'dodge all')
  end

  it 'ends an alias or link cycle instead of looping' do
    described_class.use(<<~LUA)
      local buffs = { ['A'] = { link = 'B', status = '1' }, ['B'] = { link = 'A' } }
      return { buffs = buffs, debuffs = {}, effects = {}, aliases = { ['X'] = 'Y', ['Y'] = 'X' } }
    LUA
    expect(described_class.resolve('A')).to be_present
    expect(described_class.resolve('X')).to be_nil
  end

  it 'validates a fetched body: parses, has buffs and debuffs, and resolves every name' do
    expect(described_class.validate!(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))).to be_a(described_class)
    expect { described_class.validate!('return {}') }.to raise_error(described_class::Invalid)
    expect { described_class.validate!('<html>') }.to raise_error(described_class::Invalid)
  end

  it 'returns nil for names it lacks' do
    expect(resolve('Hellfire Crest')).to be_nil
  end

  context 'with the stored source row', :status_list do
    let(:extract) { File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')) }

    it 'reads the wiki_status_list row, and re-reads it when its sha changes' do
      described_class.reset!
      Source.put(nil, described_class::KIND, extract, key: described_class::KEY)
      expect(described_class.refresh!.resolve('Accuracy Lowered 2').status_id).to eq('1032_42')
      expect(described_class.sha256).to eq(Digest::SHA256.hexdigest(extract))

      Source.put(nil, described_class::KIND, extract.sub("'1032_42'", "'1032_43'"), key: described_class::KEY)
      expect(described_class.refresh!.resolve('Accuracy Lowered 2').status_id).to eq('1032_43')
    end

    it 'falls back to an empty list, with a warning, when the row is missing' do
      described_class.reset!
      allow(Rails.logger).to receive(:warn)
      expect(described_class.refresh!.resolve('Blind')).to be_nil
      expect(described_class).to be_missing
      expect(Rails.logger).to have_received(:warn).with(/no wiki_status_list source/)
    end
  end
end
