# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::JpLocalizer do
  let(:character) { instance_double(Character, wiki_raw_jp: '<html>') }

  def version(role, name_jp: nil)
    { attrs: { variant_role: role, name_jp: name_jp, description_jp: nil } }
  end

  before do
    jp = {
      abilities: [
        { name_jp: 'ベース', effect_jp: '効果A', cooldown: 8 },
        { name_jp: 'トランス', effect_jp: '効果B' } # transform row — no cooldown, attaches
      ],
      ougi: [{ name_jp: '奥義', effect_jp: '奥義効果' }],
      support: [{ name_jp: 'サポ', effect_jp: 'サポ効果' }]
    }
    allow(Granblue::Parsers::JpWikiSkillParser).to receive(:new).with(character).and_return(instance_double(Granblue::Parsers::JpWikiSkillParser,
                                                                                                            parse: jp))
  end

  it 'aligns JP base and transform text to ability versions by position' do
    slots = [{ attrs: { kind: 'ability', position: 1 }, versions: [version('base'), version('transform_alt')] }]
    described_class.new(character).apply(slots)

    expect(slots[0][:versions][0][:attrs]).to include(name_jp: 'ベース', description_jp: '効果A')
    expect(slots[0][:versions][1][:attrs]).to include(name_jp: 'トランス', description_jp: '効果B')
  end

  it 'does not overwrite an existing name_jp' do
    slots = [{ attrs: { kind: 'ability', position: 1 }, versions: [version('base', name_jp: '既存')] }]
    described_class.new(character).apply(slots)

    expect(slots[0][:versions][0][:attrs][:name_jp]).to eq('既存')
  end

  it 'is a no-op when wiki_raw_jp is blank' do
    blank = instance_double(Character, wiki_raw_jp: '')
    slots = [{ attrs: { kind: 'ability', position: 1 }, versions: [version('base')] }]
    described_class.new(blank).apply(slots)

    expect(slots[0][:versions][0][:attrs][:name_jp]).to be_nil
  end
end
