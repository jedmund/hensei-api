# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sources::WikiStatusList do
  let(:body) { File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')) }
  let(:wiki) { instance_double(Granblue::Parsers::Wiki, fetch_raw: body) }
  let(:slept) { [] }

  def fetch = described_class.fetch!(wiki: wiki, sleeper: ->(seconds) { slept << seconds })

  it 'fetches the module once, after the wiki delay, and stores it' do
    result = fetch
    expect(wiki).to have_received(:fetch_raw).with('Module:StatusList', kind: nil).once
    expect(slept).to eq([Granblue::WikiThrottle::MIN_DELAY])
    expect(result.changed).to be(true)
    expect(Source.read(nil, :wiki_status_list, key: 'Module:StatusList')).to eq(body)
  end

  it 'leaves an unchanged list alone' do
    fetch
    expect(fetch.changed).to be(false)
  end

  it "refuses a page that doesn't parse, keeping the stored list" do
    fetch
    allow(wiki).to receive(:fetch_raw).and_return('<html>Cloudflare</html>')
    expect { fetch }.to raise_error(Granblue::Parsers::StatusList::Invalid)
    expect(Source.read(nil, :wiki_status_list, key: 'Module:StatusList')).to eq(body)
  end

  it 'refuses a gutted module (no buffs or debuffs)' do
    fetch
    allow(wiki).to receive(:fetch_raw).and_return('return { buffs = {}, debuffs = {}, effects = {}, aliases = {} }')
    expect { fetch }.to raise_error(Granblue::Parsers::StatusList::Invalid, /no buffs or debuffs/)
    expect(Source.read(nil, :wiki_status_list, key: 'Module:StatusList')).to eq(body)
  end

  it 'raises when the wiki returns nothing' do
    allow(wiki).to receive(:fetch_raw).and_return(nil)
    expect { fetch }.to raise_error(/didn't return/)
  end
end
