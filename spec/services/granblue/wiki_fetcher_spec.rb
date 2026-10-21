# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::WikiFetcher do
  let(:character) { create(:character, wiki_en: 'Old Name', wiki_raw: nil) }
  let(:waits) { [] }
  let(:requests) { [] }

  def stub_page(title, text)
    stub_request(:get, %r{\Ahttps://gbf\.wiki/api\.php})
      .with(query: hash_including(action: 'parse', page: title))
      .to_return do
        requests << [:request, title]
        { status: 200, body: JSON.generate(parse: { wikitext: { '*' => text } }), headers: { 'Content-Type' => 'application/json' } }
      end
  end

  before do
    allow(Granblue::WikiThrottle).to receive(:wait) { |seconds| requests << [:wait, seconds] }
  end

  it 'waits at least 2 seconds before following a redirect' do
    stub_page('Old Name', '#REDIRECT [[New Name]]')
    stub_page('New Name', '{{Character}}')

    expect(described_class.new.fetch_and_store(character)).to eq('{{Character}}')

    expect(requests).to eq([[:request, 'Old Name'], [:wait, 2.0], [:request, 'New Name']])
    expect(character.reload).to have_attributes(wiki_en: 'New Name', wiki_raw: '{{Character}}')
  end

  it 'keeps a longer delay for the redirect' do
    stub_page('Old Name', '#REDIRECT [[New Name]]')
    stub_page('New Name', '{{Character}}')

    described_class.new(delay: 3.0).fetch_and_store(character)

    expect(requests).to include([:wait, 3.0])
  end

  it 'makes one request and no wait without a redirect' do
    stub_page('Old Name', '{{Character}}')

    described_class.new.fetch_and_store(character)

    expect(requests).to eq([[:request, 'Old Name']])
  end
end
