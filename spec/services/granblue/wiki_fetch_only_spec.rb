# frozen_string_literal: true

require 'rails_helper'

# The editor refresh fetches pages for a preview and stores nothing until it's applied.
RSpec.describe 'Fetching wiki pages without storing them' do
  describe Granblue::WikiFetcher do
    let(:character) { create(:character, wiki_en: 'Old Title', wiki_raw: '{{Old}}') }
    let(:hook) { instance_double(Proc, call: nil) }

    it 'returns the text and leaves the record alone' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Old Title').and_return('{{New}}')

      page = described_class.new.fetch(character, before_request: hook)

      expect(page).to have_attributes(title: 'Old Title', text: '{{New}}')
      expect(hook).to have_received(:call).once
      expect(character.reload).to have_attributes(wiki_en: 'Old Title', wiki_raw: '{{Old}}', wiki_raw_fetched_at: nil)
    end

    it 'follows a redirect and reports the title it landed on' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Old Title')
                                                                       .and_return('#REDIRECT [[New Title]]')
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('New Title').and_return('{{New}}')

      page = described_class.new.fetch(character, before_request: hook)

      expect(page).to have_attributes(title: 'New Title', text: '{{New}}')
      expect(hook).to have_received(:call).twice
      expect(character.reload.wiki_en).to eq('Old Title')
    end

    it 'refuses a character without a page' do
      character.update_columns(wiki_en: '')
      expect { described_class.new.fetch(character) }.to raise_error(Granblue::WikiFetcher::MissingPageError)
    end

    it 'still stores on fetch_and_store, redirect included' do
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('Old Title')
                                                                       .and_return('#REDIRECT [[New Title]]')
      allow_any_instance_of(Granblue::Parsers::Wiki).to receive(:fetch).with('New Title').and_return('{{New}}')

      expect(described_class.new.fetch_and_store(character)).to eq('{{New}}')
      expect(character.reload).to have_attributes(wiki_en: 'New Title', wiki_raw: '{{New}}')
    end
  end

  describe Granblue::Downloaders::JpWikiDownloader do
    let(:character) { create(:character, wiki_raw_jp: '<html>old</html>') }
    let(:client) { instance_double(Granblue::Parsers::JpWiki, fetch: '<html>new</html>') }
    let(:hook) { instance_double(Proc, call: nil) }

    it 'returns the HTML and leaves the record alone' do
      html = described_class.new(character, client: client, jp_title: 'ページ').fetch(before_request: hook)

      expect(html).to eq('<html>new</html>')
      expect(client).to have_received(:fetch).with('ページ')
      expect(hook).to have_received(:call).once
      expect(character.reload).to have_attributes(wiki_raw_jp: '<html>old</html>', wiki_raw_jp_fetched_at: nil)
    end

    it 'returns nil without a title, and makes no request' do
      character.update_columns(wiki_ja: nil, name_jp: nil)
      expect(described_class.new(character, client: client).fetch(before_request: hook)).to be_nil
      expect(client).not_to have_received(:fetch)
      expect(hook).not_to have_received(:call)
    end
  end
end
