require 'rails_helper'

RSpec.describe GachaSimulation::Banner do
  let(:items) { gacha_banner_items }

  def compile(config = {})
    snapshot = { 'items' => items, 'fingerprint' => 'fixture', 'loaded_at' => Time.now.to_i }
    GachaSimulation::Compiler.new(snapshot, GachaSimulation::Configuration.normalize({ 'mode' => 'current' }.merge(config))).compile
  end

  def probabilities(entries)
    entries.to_h { |entry| [entry['item']['granblue_id'], BigDecimal(entry['probability'])] }
  end

  before { travel_to Time.utc(2026, 10, 10) }

  it "shares each rarity's truncation shortfall equally, up to its stated total" do
    GachaSimulation::BannerImport.call(gacha_banner_payload)
    result = compile
    ordinary = probabilities(result['ordinary'])
    expect(ordinary.values.sum).to be_within(BigDecimal('1e-24')).of(1)
    expect(ordinary['1040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.003'))
    expect(ordinary['1020000002']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.41'))
    guaranteed = probabilities(result['guaranteed'])
    expect(guaranteed.keys.map { |id| id[2] }.uniq).to contain_exactly('4', '3')
    expect(guaranteed['1030000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.97') / 3)
    expect(result['config']['banner']).to eq('211960')
    expect(result['banner']).to include('game_id' => '211960', 'live' => true)
  end

  it 'adds the shortfall to each shown rate, keeping it within its truncation' do
    payload = gacha_banner_payload
    payload['tabs']['1']['appear'].first['item'][1]['drop_rate'] = '1.200'
    GachaSimulation::BannerImport.call(payload)
    ordinary = probabilities(compile['ordinary'])
    expect(ordinary['1040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.0035'))
    expect(ordinary['1040000002']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.0125'))
    expect(ordinary['2040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.014'))
  end

  it 'leaves out items missing from the catalogue and shares their rate with the rest of their rarity' do
    GachaSimulation::BannerImport.call(gacha_banner_payload)
    items.reject! { |item| item['granblue_id'] == '1040000002' }
    ordinary = probabilities(compile['ordinary'])
    expect(ordinary).not_to have_key('1040000002')
    # 1.35% left over, shared between the other two SSRs
    expect(ordinary['1040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.00975'))
    expect(ordinary['2040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.02025'))
  end

  it "keeps the ordinary SSR rate in the guaranteed slot when the game doesn't publish it" do
    GachaSimulation::BannerImport.call(gacha_banner_payload(guaranteed: false))
    guaranteed = probabilities(compile['guaranteed'])
    expect(guaranteed.values.sum).to be_within(BigDecimal('1e-24')).of(1)
    expect(guaranteed['1040000001']).to be_within(BigDecimal('1e-30')).of(BigDecimal('0.003'))
    expect(guaranteed.keys.none? { |id| id[2] == '2' }).to be true
  end

  it 'uses the latest banner that has started, and replays a named one' do
    GachaSimulation::BannerImport.call(gacha_banner_payload)
    GachaSimulation::BannerImport.call(gacha_banner_payload(id: '212000', start: '2026/10/12 19:00',
                                                            finish: '2026/10/15 18:59'))
    expect(compile['config']['banner']).to eq('211960')
    travel_to Time.utc(2026, 10, 12, 10, 0)
    expect(compile['config']['banner']).to eq('212000')
    expect(compile('banner' => '211960')['config']['banner']).to eq('211960')
    travel_to Time.utc(2026, 10, 20)
    expect(compile['banner']).to include('game_id' => '212000', 'live' => false)
  end

  it 'rejects seasons, custom rates, unknown banners and an empty table' do
    expect { compile }.to raise_error(GachaSimulation::ValidationError, 'No banner rates yet')
    GachaSimulation::BannerImport.call(gacha_banner_payload)
    expect { compile('banner' => '1') }.to raise_error(GachaSimulation::ValidationError, 'Unknown banner')
    expect { compile('season' => 'summer') }.to raise_error(GachaSimulation::ValidationError)
    rates = [{ 'identity' => items.first['identity'], 'percent' => '1' }]
    expect { compile('rateups' => rates) }.to raise_error(GachaSimulation::ValidationError)
  end
end
