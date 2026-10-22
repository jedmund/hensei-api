# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::JpWikiDownloader do
  describe '.backfill' do
    let(:client) { instance_double(Granblue::Parsers::JpWiki) }

    before do
      create(:character, name_jp: 'テスト', wiki_ja: nil, wiki_raw_jp: nil)
      allow(Granblue::Parsers::JpWiki).to receive(:new).and_return(client)
      allow(client).to receive(:fetch).and_return('<html></html>')
      allow(Granblue::WikiThrottle).to receive(:wait)
      allow($stdout).to receive(:puts)
      allow(described_class).to receive(:puts)
      allow(described_class).to receive(:print)
    end

    it 'waits at least 2 seconds between requests even when asked for less' do
      described_class.backfill(model: Character, throttle: 0.1)

      expect(Granblue::WikiThrottle).to have_received(:wait).with(2.0).at_least(:once)
      expect(Granblue::WikiThrottle).not_to have_received(:wait).with(0.1)
    end

    it 'sleeps only after a real request' do
      create(:character, name_jp: 'キャッシュ', wiki_ja: nil, wiki_raw_jp: '<html>cached</html>')
      fetches = 0
      allow(client).to receive(:fetch) { (fetches += 1) && '<html></html>' }

      described_class.backfill(model: Character)

      expect(fetches).to be_positive
      expect(Granblue::WikiThrottle).to have_received(:wait).exactly(fetches).times
    end

    it 'defaults to 2 seconds' do
      expect(described_class::DEFAULT_THROTTLE).to eq(2.0)
    end
  end

  describe 'storing a character page (D35)' do
    let(:page) { '<html><head><title>t</title></head><body><div id="menu">m</div><div id="body"><p>本文</p></div></body></html>' }
    let(:client) { instance_double(Granblue::Parsers::JpWiki, fetch: page) }
    let(:character) { Character.without_skill_build { create(:character, name_jp: 'テスト', wiki_raw_jp: nil) } }

    it 'stores only div#body, dated' do
      described_class.new(character, client: client).download

      expect(Source.read(character, :wiki_raw_jp)).to eq('<div id="body"><p>本文</p></div>')
      expect(character.reload.wiki_raw_jp_fetched_at).to be_present
    end

    it 'returns the trimmed page from a fetch, so it compares equal to what is stored' do
      described_class.new(character, client: client).download(force: true)

      expect(described_class.new(character.reload, client: client).fetch).to eq(character.wiki_raw_jp)
    end

    it 'stores only div#body of a summon or weapon page too' do
      summon = create(:summon, name_jp: 'テスト')
      weapon = create(:weapon, name_jp: 'テスト')
      described_class.new(summon, client: client).download
      described_class.new(weapon, client: client).download

      expect(Source.read(summon, :wiki_raw_jp)).to eq('<div id="body"><p>本文</p></div>')
      expect(Source.read(weapon, :wiki_raw_jp)).to eq('<div id="body"><p>本文</p></div>')
      expect(summon.reload.wiki_raw_jp_fetched_at).to be_present
    end

    it 'picks summons with and without a stored page from the store' do
      stored = create(:summon, name_jp: '保存', wiki_raw_jp: '<div id="body"></div>')
      missing = create(:summon, name_jp: 'テスト')

      expect(described_class.backfill_scope(Summon, ids: nil, missing: true, force: false)).to include(missing)
      expect(described_class.backfill_scope(Summon, ids: nil, missing: true, force: false)).not_to include(stored)
    end

    it 'picks characters with and without a stored page from the store' do
      stored = Character.without_skill_build { create(:character, name_jp: '保存', wiki_raw_jp: '<div id="body"></div>') }
      character

      expect(described_class.backfill_scope(Character, ids: nil, missing: true, force: false)).to include(character)
      expect(described_class.backfill_scope(Character, ids: nil, missing: true, force: false)).not_to include(stored)
      expect(described_class.backfill_scope(Character, ids: nil, missing: false, force: true)).to contain_exactly(stored)
    end
  end
end
