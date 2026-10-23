# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::RemoteFile do
  let(:cdn) { 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/weapon' }
  let(:url) { "#{cdn}/ls/1040515700.jpg" }

  it 'returns the body as a rewindable IO' do
    stub_request(:get, url).to_return(status: 200, body: 'jpeg-bytes')

    io = described_class.open(url)
    expect(io.read).to eq('jpeg-bytes')
    io.rewind
    expect(io.read).to eq('jpeg-bytes')
  end

  it 'yields the IO when given a block' do
    stub_request(:get, url).to_return(status: 200, body: 'jpeg-bytes')

    expect(described_class.open(url) { |io| io.read }).to eq('jpeg-bytes')
  end

  it 'raises an OpenURI::HTTPError for a missing image, as open-uri did' do
    stub_request(:get, url).to_return(status: 404)

    expect { described_class.open(url) }.to raise_error(OpenURI::HTTPError, /404/)
  end

  it 'follows a redirect on the same host' do
    moved = "#{cdn}/ls/1040515700_moved.jpg"
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => '/assets_en/img/sp/assets/weapon/ls/1040515700_moved.jpg' })
    stub_request(:get, moved).to_return(status: 200, body: 'moved-bytes')

    expect(described_class.open(url).read).to eq('moved-bytes')
  end

  it 'refuses a redirect to another host without requesting it' do
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => 'https://elsewhere.example/x.jpg' })
    other = stub_request(:get, 'https://elsewhere.example/x.jpg')

    expect { described_class.open(url) }.to raise_error(described_class::RedirectRefused)
    expect(other).not_to have_been_requested
  end

  it 'refuses a redirect that drops to http on the same host' do
    stub_request(:get, url).to_return(status: 301, headers: { 'Location' => url.sub('https', 'http') })

    expect { described_class.open(url) }.to raise_error(described_class::RedirectRefused)
  end

  it 'treats a 3xx without a location as a missing image' do
    stub_request(:get, url).to_return(status: 304)

    expect { described_class.open(url) }.to raise_error(OpenURI::HTTPError, /304/)
  end

  it 'stops after too many redirects' do
    stub_request(:get, url).to_return(status: 302, headers: { 'Location' => url })

    expect { described_class.open(url) }.to raise_error(described_class::RedirectRefused, /redirects/)
    expect(a_request(:get, url)).to have_been_made.times(described_class::MAX_REDIRECTS + 1)
  end

  it 'aborts a body larger than the cap' do
    stub_request(:get, url).to_return(status: 200, body: 'x' * 11)

    expect { described_class.open(url, max_bytes: 10) }.to raise_error(described_class::TooLarge)
  end

  it 'refuses a declared Content-Length over the cap' do
    stub_request(:get, url).to_return(status: 200, body: 'x' * 11, headers: { 'Content-Length' => '11' })

    expect { described_class.open(url, max_bytes: 10) }.to raise_error(described_class::TooLarge, /11 bytes/)
  end

  it 'raises the Net timeout when the host does not answer' do
    stub_request(:get, url).to_timeout

    expect { described_class.open(url) }.to raise_error(Net::OpenTimeout)
  end

  it 'sets connection timeouts' do
    allow(Net::HTTP).to receive(:start).and_call_original
    stub_request(:get, url).to_return(status: 200, body: 'ok')

    described_class.open(url)

    expect(Net::HTTP).to have_received(:start)
      .with(anything, anything, hash_including(use_ssl: true, open_timeout: described_class::OPEN_TIMEOUT,
                                               read_timeout: described_class::READ_TIMEOUT))
  end

  it 'only fetches https URLs' do
    expect { described_class.open('http://prd-game-a-granbluefantasy.akamaized.net/x.jpg') }
      .to raise_error(described_class::Error, /https/)
    expect { described_class.open('file:///etc/passwd') }.to raise_error(described_class::Error)
  end
end
