# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::JpLocalizer do
  let(:character) { instance_double(Character, wiki_raw_jp: '<html>', style_swap: false, style_name_jp: nil) }

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
    allow(Granblue::Parsers::JpWikiSkillParser).to receive(:new) do |page|
      parsed_pages << page.wiki_raw_jp
      instance_double(Granblue::Parsers::JpWikiSkillParser, parse: jp)
    end
  end

  let(:parsed_pages) { [] }

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

  describe 'a page shared by a base character and its style shift' do
    let(:page) do
      '<div id="body"><h3>基本情報</h3><div>BASE</div>' \
        '<h3>スタイルシフト「スーパーシンダラ」</h3><div>STYLE</div>' \
        '<h3>プロフィール</h3><div>PROFILE</div></div>'
    end
    let(:slots) { [{ attrs: { kind: 'ability', position: 1 }, versions: [version('base')] }] }

    it 'reads the page without the style section for the base row' do
      base = instance_double(Character, wiki_raw_jp: page, style_swap: false, style_name_jp: nil)
      described_class.new(base).apply(slots)

      aggregate_failures do
        expect(parsed_pages.sole).to include('BASE', 'PROFILE')
        expect(parsed_pages.sole).not_to include('STYLE')
      end
    end

    it "reads only the style's own section for the style row" do
      style = instance_double(Character, wiki_raw_jp: page, style_swap: true, style_name_jp: 'スーパーシンダラ')
      described_class.new(style).apply(slots)

      aggregate_failures do
        expect(parsed_pages.sole).to include('STYLE')
        expect(parsed_pages.sole).not_to include('BASE')
        expect(parsed_pages.sole).not_to include('PROFILE')
      end
    end

    it 'leaves a style row without JP text when the page has no style section' do
      style = instance_double(Character, wiki_raw_jp: page.sub('スタイルシフト「スーパーシンダラ」', '別ページ'),
                                         style_swap: true, style_name_jp: 'スーパーシンダラ')
      described_class.new(style).apply(slots)

      aggregate_failures do
        expect(parsed_pages).to be_empty
        expect(slots[0][:versions][0][:attrs][:name_jp]).to be_nil
      end
    end
  end

  it 'is a no-op when wiki_raw_jp is blank' do
    blank = instance_double(Character, wiki_raw_jp: '')
    slots = [{ attrs: { kind: 'ability', position: 1 }, versions: [version('base')] }]
    described_class.new(blank).apply(slots)

    expect(slots[0][:versions][0][:attrs][:name_jp]).to be_nil
  end
end
