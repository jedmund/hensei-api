# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterWikiData do
  let(:fixture_dir) { Rails.root.join('spec/fixtures/character_skills') }
  let(:style1_payload) { JSON.parse(fixture_dir.join('character-cidala-gamedata.json').read) }
  let(:style2_payload) { JSON.parse(fixture_dir.join('character-super-cidala-gamedata.json').read) }

  def data_for(style_swap:, game_raw_en:, game_raw_jp: nil)
    described_class.new(build(:character, granblue_id: '3040377000', style_swap: style_swap,
                                          game_raw_en: game_raw_en, game_raw_jp: game_raw_jp))
  end

  it "ignores a style row's game data when it holds the base's (style 1) payload" do
    data = data_for(style_swap: true, game_raw_en: style1_payload, game_raw_jp: style1_payload)

    aggregate_failures do
      expect(data.game_en).to eq({})
      expect(data.game_jp).to eq({})
      expect(data.game_action('a1')).to be_nil
    end
  end

  it "uses a style row's own style-2 payload" do
    expect(data_for(style_swap: true, game_raw_en: style2_payload).game_action('a1')['class_name']).to eq('2559_3')
  end

  it "ignores a base row's game data when it holds a style-2 payload" do
    expect(data_for(style_swap: false, game_raw_en: style2_payload).game_en).to eq({})
  end

  it "uses a base row's own style-1 payload" do
    expect(data_for(style_swap: false, game_raw_en: style1_payload).game_action('a1')['class_name']).to eq('1640_1')
  end

  it 'keeps a payload that has no style' do
    payload = style1_payload.except('style')

    expect(data_for(style_swap: true, game_raw_en: payload).game_action('a1')['class_name']).to eq('1640_1')
  end
end
