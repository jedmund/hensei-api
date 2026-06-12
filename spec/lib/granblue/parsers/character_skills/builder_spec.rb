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
end
