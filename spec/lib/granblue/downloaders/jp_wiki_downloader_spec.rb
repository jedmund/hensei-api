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

  describe 'stored percent-encoded titles' do
    let(:siegfried) do
      '%E3%82%B8%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AA%E3%83%BC%E3%83%88+%28SSR%29' \
        '%E3%82%A2%E3%83%8A%E3%82%B6%E3%83%BC%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3'
    end

    # Stored as legacy rows are: update_columns skips the model's normalization.
    def stored(factory, wiki_ja, **attributes)
      record = Character.without_skill_build { create(factory, wiki_raw_jp: nil, **attributes) }
      record.update_columns(wiki_ja: wiki_ja)
      record
    end

    it 'resolves the plain title from UTF-8 and EUC-JP encodings' do
      expect(described_class.resolve_title(stored(:character, siegfried)))
        .to eq('ジークフリート (SSR)アナザーバージョン')
      expect(described_class.resolve_title(stored(:summon, '%BE%A4%B4%AD%C0%D0%2F%A5%B0%A5%E9%A5%CB%20%28SSR%29')))
        .to eq('召喚石/グラニ (SSR)')
      expect(described_class.resolve_title(stored(:weapon, '%A5%DE%A5%F3%A5%C7%A5%C8%20%28SSR%29')))
        .to eq('武器/マンデト (SSR)')
      expect(described_class.resolve_title(stored(:weapon, '%C9%F0%B4%EF%B3%B5%CD%D7%2F%BB%CD%BE%DD%C9%F0%B4%EF')))
        .to eq('武器概要/四象武器')
    end

    it 'fetches the decoded title' do
      client = instance_double(Granblue::Parsers::JpWiki, fetch: '<div id="body"></div>')
      described_class.new(stored(:character, siegfried), client: client).download

      expect(client).to have_received(:fetch).with('ジークフリート (SSR)アナザーバージョン')
    end

    it 'builds the URL from the decoded title, UTF-8 encoded' do
      expect(Granblue::Parsers::JpWiki.new.url_for('%A5%D7%A5%EA%A5%AD%A5%E5%A5%A2%20%28SSR%29'))
        .to eq("https://gbf-wiki.com/?#{URI.encode_www_form_component('プリキュア (SSR)')}")
    end

    it 'reports an undecodable title in the backfill instead of fetching it' do
      broken = stored(:character, '%A5%B7%A5%E3%A5%EB%A5%ED%A5%C3%A5%C6%20%28SSR%29%A5%')
      client = instance_double(Granblue::Parsers::JpWiki)
      allow(client).to receive(:fetch)
      allow(Granblue::Parsers::JpWiki).to receive(:new).and_return(client)
      allow(Granblue::WikiThrottle).to receive(:wait)
      allow($stdout).to receive(:puts)
      allow(described_class).to receive(:puts)
      allow(described_class).to receive(:print)

      result = described_class.backfill(model: Character, ids: [broken.granblue_id])

      expect(client).not_to have_received(:fetch)
      expect(result[:errors].map(&:message)).to contain_exactly(a_string_including('stored Japanese wiki title'))
      expect(Granblue::WikiThrottle).not_to have_received(:wait)
    end
  end
end
