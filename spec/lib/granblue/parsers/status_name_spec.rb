# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusName do
  before { allow(described_class).to receive(:exceptions).and_return(Set['other self']) }

  it 'splits the trailing variant number off a status name' do
    expect(described_class.split('DEF Down 4')).to eq(['DEF Down', 4])
    expect(described_class.split("Hellfire Crest\t3 ")).to eq(['Hellfire Crest', 3])
    expect(described_class.split('Veil')).to eq(['Veil', nil])
    expect(described_class.split('50% DMG Cut')).to eq(['50% DMG Cut', nil])
  end

  it 'maps an approved alias to its canonical status' do
    allow(Granblue::Parsers::StatusAliases).to receive(:map).and_return('def lowered' => 'DEF Down')
    expect(described_class.split('DEF Lowered 3')).to eq(['DEF Down', 3])
    expect(described_class.split('def  lowered')).to eq(['DEF Down', nil])
  end

  it 'refuses an alias that points at another alias' do
    file = Tempfile.new(['aliases', '.json'])
    file.write(JSON.generate([{ wiki_name: 'A', name_en: 'B', reason: 'x' }, { wiki_name: 'B', name_en: 'C', reason: 'x' }]))
    file.close
    expect { Granblue::Parsers::StatusAliases.load(file.path) }.to raise_error(Granblue::Parsers::StatusAliases::Invalid, /B/)
  ensure
    file&.unlink
  end

  it 'is idempotent: the base of a base is itself' do
    Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
    allow(Granblue::Parsers::StatusAliases).to receive(:map).and_return('def lowered' => 'DEF Down', 'blinded' => 'Blind')
    names = ['DEF Down 4', 'DEF Lowered', 'Blind', 'Blinded', 'Accuracy Lowered 2', 'Other Self', 'Hellfire Crest 3', 'Charge Boost']
    expect(names.map { |n| described_class.base(described_class.base(n)) }).to eq(names.map { |n| described_class.base(n) })
  end

  it 'loads the shipped aliases file' do
    expect { Granblue::Parsers::StatusAliases.load }.not_to raise_error
  end

  it 'keeps the number of a listed exception' do
    expect(described_class.split('Other Self 1')).to eq(['Other Self 1', nil])
  end

  it 'reads the shipped exceptions file' do
    expect(described_class.load_exceptions).to be_a(Set)
  end

  it 'asks the status list first, then strips the number for names it lacks' do
    Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
    resolved = described_class.resolve('DEF Down 4')
    expect([resolved.name, resolved.variant, resolved.game_status_id]).to eq(['DEF Lowered', 4, '1020_14'])
    expect(described_class.split('Charm')).to eq(['Charm', nil])
    expect(described_class.split('Blind')).to eq(['Blinded', nil])
    expect(described_class.split('Hellfire Crest 3')).to eq(['Hellfire Crest', 3])
  end

  it 'classifies a mention: n= is uses, a matching t= is turns' do
    expect(described_class.mention_kind(1, 'n' => '1')).to eq('uses')
    expect(described_class.mention_kind(1, 't' => '1T', 'n' => '6')).to eq('turns')
    expect(described_class.mention_kind(3, 'n' => '2')).to eq('uses')
    expect(described_class.mention_kind(2, 't' => '2.5T')).to eq('turns')
    expect(described_class.mention_kind(3, 't' => '180s')).to be_nil
    expect(described_class.mention_kind(nil, 't' => '3T')).to be_nil
  end

  it "votes a family's kind, and leaves a split vote undecided" do
    expect(described_class.family_kind(turns: 9, other_turns: 1, plain: 4)).to eq('turns')
    expect(described_class.family_kind(plain: 6, other_turns: 2)).to eq('level')
    expect(described_class.family_kind(uses: 3)).to eq('uses')
    expect(described_class.family_kind(turns: 2, other_turns: 2)).to be_nil
  end

  it 'gives the base of a display id' do
    expect(%w[1020_14 1019_0_40 61433 1020].map { |id| described_class.base_game_id(id) }).to eq(%w[1020 1019 6143 1020])
  end

  it "shows a name without the wiki's trailing level number, unless it's an exception" do
    allow(described_class).to receive(:exceptions).and_return(Set['other self'])
    expect(['Jade Crest 1', 'Spirit (Anne) 1', 'Output 10%', 'Veil', 'Other Self 1'].map { |name| described_class.display(name) })
      .to eq(['Jade Crest', 'Spirit (Anne)', 'Output 10%', 'Veil', 'Other Self 1'])
  end

  it 'keeps the number as the variant when an alias folds a numbered entry into another status (D60)' do
    Granblue::Parsers::StatusList.use(<<~LUA)
      local buffs = { ['Spirit 1'] = { status = '16401' }, ['Spirit 5'] = { status = '16405' }, ['Spirit'] = { link = 'Spirit 5' } }
      return { buffs = buffs, debuffs = {}, effects = {}, aliases = {} }
    LUA
    allow(Granblue::Parsers::StatusAliases).to receive(:map).and_return('spirit 1' => 'Spirit', 'spirit 5' => 'Spirit')
    expect(['Spirit 1', 'Spirit 5', 'Spirit'].map { |name| described_class.resolve(name).then { |r| [r.name, r.variant, r.game_status_id] } })
      .to eq([['Spirit', 1, '16401'], ['Spirit', 5, '16405'], ['Spirit', nil, '16405']])
  end
end
