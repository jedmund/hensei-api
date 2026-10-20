# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::JpWikiDownloader do
  describe '.backfill' do
    let(:client) { instance_double(Granblue::Parsers::JpWiki) }

    before do
      create(:character, name_jp: 'テスト', wiki_ja: nil, wiki_raw_jp: nil)
      allow(Granblue::Parsers::JpWiki).to receive(:new).and_return(client)
      allow(client).to receive(:fetch).and_return('<html></html>')
      allow(described_class).to receive(:sleep)
      allow(described_class).to receive(:puts)
      allow(described_class).to receive(:print)
    end

    it 'waits at least 2 seconds between requests even when asked for less' do
      described_class.backfill(model: Character, throttle: 0.1)

      expect(described_class).to have_received(:sleep).with(2.0).at_least(:once)
      expect(described_class).not_to have_received(:sleep).with(0.1)
    end

    it 'defaults to 2 seconds' do
      expect(described_class::DEFAULT_THROTTLE).to eq(2.0)
    end
  end
end
