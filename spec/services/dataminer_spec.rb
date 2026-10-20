# frozen_string_literal: true

require 'rails_helper'

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

  describe 'pace' do
    it 'waits at least 2 seconds between game requests' do
      expect(miner.delay).to eq(2.0)
      expect(described_class.new(page: 'archive', access_token: 't', wing: 'w', midship: 'm', delay: 0.5).delay).to eq(2.0)
      expect(described_class.new(page: 'archive', access_token: 't', wing: 'w', midship: 'm', delay: 3).delay).to eq(3.0)
    end

    it 'says when a requested delay was raised' do
      notes = []
      expect(described_class.clamp_delay('1', warn: notes.method(:<<))).to eq(2.0)
      expect(notes.first).to include('below the 2.0s minimum')
      expect(described_class.clamp_delay(nil)).to eq(2.0)
    end

    it 'sleeps the delay between characters, and between styles' do
      stub_style(1, style1_payload)
      stub_style(2, style2_payload)
      other = create(:character, granblue_id: '3040000901', game_raw_en: nil)
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => other.granblue_id))
                                                 .to_return(status: 200, body: style1_payload.merge('id' => other.granblue_id,
                                                                                                    'style_list' => []).to_json)

      miner.fetch_characters(%w[3040377000 3040000901])

      expect(miner).to have_received(:sleep).with(2.0).twice
    end
  end

  describe 'authentication failure' do
    let(:ids) { %w[3040000911 3040000912 3040000913] }

    before do
      ids.each { |id| create(:character, granblue_id: id, game_raw_en: nil) }
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000911'))
                                                 .to_return(status: 200, body: style1_payload.merge('id' => '3040000911',
                                                                                                    'style_list' => []).to_json)
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000912'))
                                                 .to_return(status: 200, body: '{"auth_status":"require_auth"}')
    end

    it 'stops the run at the first one and keeps the ids it did not get to' do
      miner.fetch_characters(ids)

      expect(WebMock).not_to have_requested(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000913'))
      expect(miner.remaining_ids).to eq(%w[3040000912 3040000913])
      expect(miner.summary.fetched).to eq(1)
      expect(miner.summary.errors.map(&:granblue_id)).to eq(['3040000912'])
    end

    it 'stops a fetch_all run the same way' do
      # Only this example's characters are missing game data.
      Character.where.not(granblue_id: ids).find_each { |c| put_source(c, :game_raw_en, { 'id' => 'x' }) }
      miner.fetch_all_characters(only_missing: true)

      expect(miner.remaining_ids).to eq(%w[3040000912 3040000913])
    end

    it 'carries on after other errors' do
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000912'))
                                                 .to_timeout
      stub_request(:post, %r{archive/npc_detail}).with(body: hash_including('character_id' => '3040000913'))
                                                 .to_return(status: 200, body: style1_payload.merge('id' => '3040000913',
                                                                                                    'style_list' => []).to_json)

      miner.fetch_characters(ids)

      expect(miner.remaining_ids).to be_nil
      expect(miner.summary.fetched).to eq(2)
    end
  end
end
