require 'rails_helper'

RSpec.describe GachaSimulation::BannerImport do
  it "stores the banner, its Tokyo times and each tab's rates" do
    result = described_class.call(gacha_banner_payload)
    banner = GachaBanner.find_by!(game_id: '211960')
    expect(result).to include('game_id' => '211960', 'items' => 9)
    expect(banner.starts_at).to eq(Time.utc(2026, 10, 9, 10, 0))
    expect(banner.ends_at).to eq(Time.utc(2026, 10, 12, 10, 0))
    expect(banner.rarity_rates).to eq('1' => { '3' => '0.03', '2' => '0.15', '1' => '0.82' },
                                      '2' => { '3' => '0.03', '2' => '0.97' })
    expect(banner.rates.where(tab: 2).count).to eq(6)
    rate_up = banner.rates.find_by!(tab: 1, reward_id: '1040000001')
    expect(rate_up).to have_attributes(rarity: 3, category: 'characterWeapon', percent: BigDecimal('0.3'), rate_up: true)
    expect(banner.rates.find_by!(tab: 1, reward_id: '2020000001')).to have_attributes(rarity: 1, category: 'summon')
  end

  it 'replaces a banner imported again' do
    described_class.call(gacha_banner_payload)
    described_class.call(gacha_banner_payload(guaranteed: false))
    expect(GachaBanner.count).to eq(1)
    expect(GachaBannerRate.count).to eq(9)
  end

  it 'counts items missing from the catalogue' do
    create(:weapon, granblue_id: '1040000001')
    expect(described_class.call(gacha_banner_payload)['unmatched']).to eq(8)
  end

  it 'rejects malformed payloads without storing anything' do
    bad = [
      nil, {}, gacha_banner_payload.merge('tabs' => {}),
      gacha_banner_payload.tap { |p| p['banner']['id'] = '../1' },
      gacha_banner_payload.tap { |p| p['banner']['service_start'] = 'soon' },
      gacha_banner_payload.tap { |p| p['tabs']['1']['ratio'][0]['ratio'] = '4.00%' },
      gacha_banner_payload.tap { |p| p['tabs']['1']['ratio'][0]['rare'] = 'URレア' },
      gacha_banner_payload.tap { |p| p['tabs']['1']['appear'][0]['item'][0]['drop_rate'] = '1e3' },
      gacha_banner_payload.tap { |p| p['tabs']['1']['appear'][0]['item'][0]['reward_id'] = 'x' },
      gacha_banner_payload.tap { |p| p['tabs']['1']['appear'][0]['category'] = 9 },
      gacha_banner_payload.tap { |p| p['tabs']['1']['appear'] << p['tabs']['1']['appear'][0] }
    ]
    bad.each do |payload|
      expect { described_class.call(payload) }.to raise_error(GachaSimulation::ValidationError)
    end
    expect(GachaBanner.count).to eq(0)
  end
end
