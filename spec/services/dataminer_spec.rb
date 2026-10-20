# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

# The style-2 payload (character-super-cidala-gamedata.json) is hand-made from the real
# style-1 capture until the game's own style-2 response lands (board decision D9).
RSpec.describe Dataminer do
  let(:fixture_dir) { Rails.root.join('spec/fixtures/character_skills') }
  let(:style1_payload) { JSON.parse(fixture_dir.join('character-cidala-gamedata.json').read) }
  let(:style2_payload) { JSON.parse(fixture_dir.join('character-super-cidala-gamedata.json').read) }

  let!(:base) { create(:character, granblue_id: '3040377000', game_raw_en: nil, game_raw_jp: nil) }
  let!(:style) do
    create(:character, granblue_id: '3040377000', style_swap: true, game_raw_en: nil, game_raw_jp: nil)
  end

  let(:miner) do
    described_class.new(page: 'archive', access_token: 'token', wing: 'wing', midship: 'midship').tap do |m|
      m.instance_variable_set(:@logger, Logger.new(IO::NULL))
      allow(m).to receive(:sleep)
    end
  end

  def stub_style(style, payload)
    stub_request(:post, %r{\Ahttps://game\.granbluefantasy\.jp/archive/npc_detail})
      .with(body: hash_including('style' => style, 'character_id' => '3040377000'))
      .to_return(status: 200, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '#fetch_character' do
    it 'stores a style-2 response on the style row' do
      request = stub_style(2, style2_payload)

      miner.fetch_character('3040377000', style: 2, other_styles: false)

      aggregate_failures do
        expect(request).to have_been_requested.once
        expect(style.reload.game_raw_en['style']).to eq(2)
        expect(style.game_raw_en.dig('ability', '1', 'class_name')).to eq('2559_3')
        expect(base.reload.game_raw_en).to be_nil
      end
    end

    it "follows style 1's style_list to fetch and store the open style 2" do
      style1 = stub_style(1, style1_payload)
      style2 = stub_style(2, style2_payload)

      miner.fetch_character('3040377000')

      aggregate_failures do
        expect(style1).to have_been_requested.once
        expect(style2).to have_been_requested.once
        expect(base.reload.game_raw_en.dig('ability', '1', 'class_name')).to eq('1640_1')
        expect(style.reload.game_raw_en.dig('ability', '1', 'class_name')).to eq('2559_3')
      end
    end

    it 'does not fetch a style the style_list marks as not open' do
      closed = style1_payload.merge('style_list' => style1_payload['style_list'].map do |entry|
        entry['style'] == 2 ? entry.merge('is_open' => false) : entry
      end)
      stub_style(1, closed)
      style2 = stub_style(2, style2_payload)

      miner.fetch_character('3040377000')

      expect(style2).not_to have_been_requested
    end

    it 'does not fetch or store a style that has no row' do
      with_style3 = style1_payload.merge('style_list' => style1_payload['style_list'] +
        [{ 'style' => 3, 'is_open' => true, 'name' => 'Third Style' }])
      stub_style(1, with_style3)
      stub_style(2, style2_payload)
      style3 = stub_style(3, style2_payload.merge('style' => 3))

      miner.fetch_character('3040377000')
      miner.fetch_character('3040377000', style: 3, other_styles: false)

      aggregate_failures do
        expect(style3).to have_been_requested.once
        expect(base.reload.game_raw_en['style']).to eq(1)
        expect(style.reload.game_raw_en['style']).to eq(2)
      end
    end

    it 'does not store a response that is not a character payload' do
      stub_style(2, { 'popup' => { 'body' => 'Maintenance' } })

      miner.fetch_character('3040377000', style: 2, other_styles: false)

      expect(style.reload.game_raw_en).to be_nil
    end

    it 'does not store a response whose style differs from the one requested' do
      stub_style(2, style1_payload)

      miner.fetch_character('3040377000', style: 2, other_styles: false)

      expect([base.reload.game_raw_en, style.reload.game_raw_en]).to eq([nil, nil])
    end

    it 'writes game_raw_jp for lang: jp' do
      stub_style(2, style2_payload)

      miner.fetch_character('3040377000', style: 2, lang: 'jp', other_styles: false)

      expect([style.reload.game_raw_jp['style'], style.game_raw_en]).to eq([2, nil])
    end
  end

  describe '#fetch_all_characters' do
    it 'fetches base rows only and fills style rows from the style_list' do
      # Other characters in the test database get an empty archive response.
      stub_request(:post, %r{/archive/npc_detail}).to_return(status: 200, body: '{}')
      style1 = stub_style(1, style1_payload)
      style2 = stub_style(2, style2_payload)

      miner.fetch_all_characters(only_missing: true)

      aggregate_failures do
        expect(style1).to have_been_requested.once
        expect(style2).to have_been_requested.once
        expect(style.reload.game_raw_en['style']).to eq(2)
      end
    end
  end

  describe '#fetch_characters' do
    it 'fetches only the requested style when one is given' do
      style1 = stub_style(1, style1_payload)
      style2 = stub_style(2, style2_payload)

      miner.fetch_characters(['3040377000'], style: 2)

      aggregate_failures do
        expect(style1).not_to have_been_requested
        expect(style2).to have_been_requested.once
      end
    end
  end
end
