require 'rails_helper'
require Rails.root.join('script/fetch_gacha_rates')

RSpec.describe GachaRatesFetcher do
  let(:dir) { Dir.mktmpdir }
  let(:env) do
    { 'GBF_UID' => '123', 'GBF_COOKIE_FILE' => File.join(dir, 'cookies.json'),
      'GACHA_RATES_URL' => 'https://api.example/v1/gacha/banners', 'GACHA_RATES_TOKEN' => 'secret' }
  end
  let(:fetcher) { described_class.new(env) }
  let(:payload) { gacha_banner_payload }
  let(:list) { { 'legend' => { 'lineup' => [payload['banner'].merge('id' => '211961', 'times' => '1'), payload['banner']] } } }
  let(:requests) { [] }

  after { FileUtils.remove_entry(dir) }

  def respond(path)
    case path
    when '/' then '<script>Game = {"version": "1791424018"}</script>'
    when '/gacha/list' then JSON.generate(list)
    when %r{\A/gacha/provision_ratio/legend/211960/([12])\z} then JSON.generate(payload['tabs'][Regexp.last_match(1)])
    end
  end

  before do
    allow(fetcher).to receive(:get) do |uri, headers: {}, **|
      requests << [uri.to_s, headers]
      respond(uri.path) || raise("unexpected #{uri}")
    end
    allow(fetcher).to receive(:upload) { |body| (@uploaded = body) && { 'game_id' => '211960', 'items' => 9, 'unmatched' => 0 } }
    expect { fetcher.import_cookies("Cookie: wing=abc; t=1; access_gbtk=x; access_gbtk=y\n") }.to output.to_stdout
  end

  it 'imports a copied Cookie header, keeping the first of a repeated name' do
    expect(JSON.parse(File.read(env['GBF_COOKIE_FILE']))).to eq('wing' => 'abc', 't' => '1', 'access_gbtk' => 'x')
    expect(File.stat(env['GBF_COOKIE_FILE']).mode & 0o777).to eq(0o600)
  end

  it "uploads the 10-part banner's lineup entry and both rate tabs, with the game's version" do
    expect { fetcher.run }.to output(/Uploaded banner 211960/).to_stdout
    expect(@uploaded['banner']).to include('id' => '211960', 'service_start' => '2026/10/9 19:00')
    expect(@uploaded['tabs'].keys).to eq(%w[1 2])
    expect(GachaSimulation::BannerImport.call(JSON.parse(JSON.generate(@uploaded)))['items']).to eq(9)
    ratio = requests.find { |url, _| url.include?('provision_ratio') }
    expect(ratio[0]).to include('uid=123')
    expect(ratio[1]).to include('X-Version' => '1791424018')
  end

  context 'while the uploaded banner is running' do
    before { travel_to Time.zone.parse('2026-10-10 12:00 JST') }

    it "doesn't contact the game until the banner ends, unless forced" do
      expect { fetcher.run }.to output(/Uploaded/).to_stdout
      state = JSON.parse(File.read(File.join(dir, 'cookies-state.json')))
      expect(state).to eq('game_id' => '211960', 'ends_at' => '2026-10-12T19:00:00+09:00')

      requests.clear
      expect { fetcher.run }.to output(/runs until 2026-10-12T19:00:00\+09:00/).to_stdout
      expect(requests).to be_empty

      forced = described_class.new(env, force: true)
      allow(forced).to receive(:get) { |uri, **| respond(uri.path) }
      allow(forced).to receive(:upload).and_return({ 'game_id' => '211960', 'items' => 9, 'unmatched' => 0 })
      expect { forced.run }.to output(/Uploaded/).to_stdout
    end
  end

  it 'checks the game after the banner ends, and uploads the next one once listed' do
    travel_to Time.zone.parse('2026-10-10 12:00 JST')
    expect { fetcher.run }.to output(/Uploaded/).to_stdout

    travel_to Time.zone.parse('2026-10-12 19:05 JST')
    requests.clear
    expect { fetcher.run }.to output(/unchanged/).to_stdout
    expect(requests.map(&:first)).to all(satisfy { |url| !url.include?('provision_ratio') })

    payload['banner'].merge!('id' => '211962', 'service_end' => '6:59 p.m., Oct 15, 2026 (JST)')
    allow(fetcher).to receive(:upload).and_return({ 'game_id' => '211962', 'items' => 9, 'unmatched' => 0 })
    allow(fetcher).to receive(:rates).and_return(payload['tabs']['1'])
    expect { fetcher.run }.to output(/Uploaded banner 211962/).to_stdout
    state = JSON.parse(File.read(File.join(dir, 'cookies-state.json')))
    expect(state).to eq('game_id' => '211962', 'ends_at' => '2026-10-15T19:00:00+09:00')
  end

  it 'records the end of a banner it already uploaded, so older state stops checking hourly' do
    travel_to Time.zone.parse('2026-10-10 12:00 JST')
    File.write(File.join(dir, 'cookies-state.json'), JSON.generate('game_id' => '211960', 'date' => '2026-10-10'))
    expect { fetcher.run }.to output(/unchanged/).to_stdout
    expect(JSON.parse(File.read(File.join(dir, 'cookies-state.json')))['ends_at']).to eq('2026-10-12T19:00:00+09:00')
  end

  it 'fails, and alerts, when the account is signed out' do
    allow(fetcher).to receive(:get).and_return('<html>login</html>')
    allow(fetcher).to receive(:alert)
    expect { fetcher.run }.to raise_error(SystemExit).and output(/signed out/).to_stderr
    expect(fetcher).to have_received(:alert).with(/signed out/)
  end

  it 'keeps cookies the game sets and drops the ones it expires' do
    fetcher.instance_variable_set(:@cookies, { 'wing' => 'abc', 't' => '1' })
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response.add_field('Set-Cookie', 'wing=new; path=/; HttpOnly')
    response.add_field('Set-Cookie', 't=; expires=Thu, 01 Jan 1970 00:00:00 GMT')
    response.add_field('Set-Cookie', 'midship=m; Max-Age=2592000')
    fetcher.send(:keep_cookies, response)
    expect(fetcher.instance_variable_get(:@cookies)).to eq('wing' => 'new', 'midship' => 'm')
  end
end
