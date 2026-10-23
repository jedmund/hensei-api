# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::Builder do
  let(:fixtures) { Rails.root.join('spec/fixtures/character_skills') }
  let(:character) do
    build(
      :character, granblue_id: '3040252000', name_en: 'Vikala',
      wiki_raw: File.read(fixtures.join('character-vikala-wikidata.txt')),
      game_raw_en: JSON.parse(File.read(fixtures.join('character-vikala-gamedata.json')))
    )
  end
  let(:data) { Granblue::Parsers::CharacterWikiData.new(character) }
  let(:effect_parser) { Granblue::Parsers::CharacterSkills::EffectParser.new({ by_name: {}, by_id: {} }) }

  subject(:builder) { described_class.new(character, data: data, effect_parser: effect_parser) }

  it 'returns a graph with the character id, ability/ougi/support slots, and links to built versions only' do
    graph = builder.build
    version_keys = graph[:slots].flat_map { |slot| slot[:versions].map { |v| v[:key] } }

    aggregate_failures do
      expect(graph[:character_granblue_id]).to eq('3040252000')
      expect(graph[:slots].map { |slot| slot[:attrs][:kind] }.uniq).to contain_exactly('ability', 'ougi', 'support')
      expect(graph[:links]).to be_present
      graph[:links].each { |link| expect(version_keys).to include(link[:from_version_key], link[:to_version_key]) }
    end
  end

  it 'reuses the injected effect parser instance' do
    expect(builder.effect_parser).to be(effect_parser)
  end

  describe 'game_icon resolution' do
    let(:wiki_raw) do
      File.read(fixtures.join('character-vikala-wikidata.txt'))
          .sub(/^\|a1_icon=.*$/, '|a1_icon= Ability_m_9999_1.png')
    end
    let(:game_raw_en) { nil }
    let(:character) do
      build(:character, granblue_id: '3040252000', name_en: 'Vikala', wiki_raw: wiki_raw, game_raw_en: game_raw_en)
    end
    let(:snapshot_entries) { [] }

    def first_ability_version(graph)
      slot = graph[:slots].find { |s| s[:attrs][:kind] == 'ability' && s[:attrs][:position] == 1 }
      slot[:versions].find { |v| v[:attrs][:ordinal] == 1 }
    end

    def entry(name_en:, game_icon:)
      { granblue_id: '3040252000', style: 1, kind: 'ability', position: 1, ordinal: 1, name_en: name_en, game_icon: game_icon }
    end

    before { put_icon_snapshot(snapshot_entries) }

    context 'with game data' do
      let(:game_raw_en) { JSON.parse(File.read(fixtures.join('character-vikala-gamedata.json'))) }
      let(:snapshot_entries) { [entry(name_en: 'Ring the Dormouse', game_icon: '5555_1')] }

      it 'prefers the game class_name over the snapshot' do
        version = first_ability_version(builder.build)
        expect(version[:attrs][:game_icon]).to eq('1065_1')
        expect(version[:game_icon_source]).to eq('game')
      end
    end

    context 'without game data and a matching snapshot entry' do
      let(:snapshot_entries) { [entry(name_en: 'Ring the Dormouse', game_icon: '5555_1')] }

      it 'takes the snapshot icon' do
        version = first_ability_version(builder.build)
        expect(version[:attrs][:game_icon]).to eq('5555_1')
        expect(version[:game_icon_source]).to eq('snapshot')
      end
    end

    context 'with a snapshot entry under another name' do
      let(:snapshot_entries) { [entry(name_en: 'Some Other Ability', game_icon: '5555_1')] }

      it 'falls back to the wiki stem' do
        version = first_ability_version(builder.build)
        expect(version[:attrs][:game_icon]).to eq('9999_1')
        expect(version[:game_icon_source]).to eq('wiki')
        expect(version[:attrs]).not_to have_key(:game_icon_source)
      end
    end

    context 'with a matching entry under another ordinal of the same slot' do
      let(:snapshot_entries) { [entry(name_en: 'Ring the Dormouse', game_icon: '5555_1').merge(ordinal: 7)] }

      it 'takes the snapshot icon' do
        expect(first_ability_version(builder.build)[:attrs][:game_icon]).to eq('5555_1')
      end
    end

    context 'with same-named entries in the slot that disagree' do
      let(:snapshot_entries) do
        [entry(name_en: 'Ring the Dormouse', game_icon: '5555_1').merge(ordinal: 7),
         entry(name_en: 'Ring the Dormouse', game_icon: '6666_1').merge(ordinal: 8)]
      end

      it 'falls back to the wiki stem' do
        expect(first_ability_version(builder.build)[:attrs][:game_icon]).to eq('9999_1')
      end
    end

    context 'without a snapshot entry' do
      it 'falls back to the wiki stem' do
        expect(first_ability_version(builder.build)[:attrs][:game_icon]).to eq('9999_1')
      end
    end

    context 'without any icon' do
      let(:wiki_raw) { File.read(fixtures.join('character-vikala-wikidata.txt')).sub(/^\|a1_icon=.*$/, '|a1_icon=') }

      it 'records no source' do
        version = first_ability_version(builder.build)
        expect(version[:attrs][:game_icon]).to be_nil
        expect(version[:game_icon_source]).to be_nil
      end
    end

    context 'for a style row' do
      let(:character) do
        build(:character, granblue_id: '3040252000', name_en: 'Vikala', wiki_raw: wiki_raw, style_swap: true)
      end
      let(:snapshot_entries) { [entry(name_en: 'Ring the Dormouse', game_icon: '5555_1')] }

      it 'does not take the base row\'s snapshot entry' do
        expect(first_ability_version(builder.build)[:attrs][:game_icon]).to eq('9999_1')
      end
    end
  end
end
