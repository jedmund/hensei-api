require 'rails_helper'

RSpec.describe 'Gacha cache and purchase estimates' do
  it 'retains immutable catalogue snapshots for at most an hour during failures' do
    catalogue = GachaSimulation::Catalogue
    original = catalogue.instance_variable_get(:@snapshot)
    begin
      catalogue.instance_variable_set(:@snapshot, nil)
      allow(catalogue).to receive(:load_items).and_return([{ 'identity' => 'Weapon:fixture', 'name' => 'item' }])
      snapshot = catalogue.snapshot
      expect(snapshot['items'].first).to be_frozen
      travel 901
      allow(catalogue).to receive(:load_items).and_raise('offline')
      expect(catalogue.snapshot).to equal(snapshot)
      travel 2700
      expect { catalogue.snapshot }.to raise_error(GachaSimulation::Unavailable)
    ensure
      travel_back
      catalogue.instance_variable_set(:@snapshot, original)
    end
  end

  it 'identifies the character a weapon recruits' do
    character = create(:character, name_en: 'Vira', name_jp: 'ヴィーラ')
    weapon = create(:weapon, rarity: 3, recruits: character.granblue_id, release_date: Date.new(2026, 3, 16))
    item = GachaSimulation::Catalogue.send(:load_items).find { |row| row['drawable_id'] == weapon.id }
    expect(item['category']).to eq('characterWeapon')
    expect(item['release_date']).to eq('2026-03-16')
    expect(item['recruits']).to include('granblue_id' => character.granblue_id, 'en' => 'Vira', 'ja' => 'ヴィーラ')
  end

  it 'includes the season and series a recruited character is tagged with' do
    series = CharacterSeries.create!(name_en: 'Zodiac', name_jp: '十二神将', slug: 'zodiac-spec', order: 1)
    character = create(:character, season: 3)
    character.character_series_records << series
    weapon = create(:weapon, rarity: 3, recruits: character.granblue_id)
    item = GachaSimulation::Catalogue.send(:load_items).find { |row| row['drawable_id'] == weapon.id }
    expect(item['recruits']).to include(
      'season' => 3,
      'series' => [{ 'id' => series.id, 'slug' => 'zodiac-spec', 'name' => { 'en' => 'Zodiac', 'ja' => '十二神将' } }]
    )
  end

  it 'links a weapon to the base character when the character has a Style Shift' do
    character = create(:character, name_en: 'Cidala', name_jp: 'シンダラ')
    create(:character, granblue_id: character.granblue_id, name_en: 'Cidala', name_jp: 'シンダラ',
                       style_swap: true, style_name_en: 'Super Cidala')
    weapon = create(:weapon, rarity: 3, recruits: character.granblue_id)
    item = GachaSimulation::Catalogue.send(:load_items).find { |row| row['drawable_id'] == weapon.id }
    expect(item['recruits']).to include('granblue_id' => character.granblue_id, 'en' => 'Cidala', 'ja' => 'シンダラ')
  end

  it 'uses JPY divided by JPY-per-USD and retains a dated stale quote for seven days' do
    redis = double('redis')
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    quote = { 'provider' => 'Frankfurter / ECB', 'date' => (Date.today - 7).iso8601, 'jpy_per_usd' => '150' }
    allow(redis).to receive(:get).and_return(JSON.generate(quote))
    cost = GachaSimulation::ExchangeRate.cost('10')
    expect(cost['jpy']).to eq('3150.0')
    expect(cost['usd']).to eq('21.0')
    expect(cost['exchange_rate']['stale']).to be true
    quote['date'] = (Date.today - 8).iso8601
    allow(redis).to receive(:get).and_return(JSON.generate(quote))
    expect(GachaSimulation::ExchangeRate.cost('10')['usd']).to be_nil
    expect(GachaSimulation::ExchangeRate.cost('90071992547409930')['jpy']).to eq('28372677652434127950.0')
  end

  it 'keeps the last quote on provider failure and filters ECB' do
    uri = URI('https://api.frankfurter.dev/v2/rate/USD/JPY?providers=ecb')
    http = double('http')
    allow(Net::HTTP).to receive(:start).and_yield(http)
    expect(http).to receive(:get).with(uri.request_uri).and_return(Net::HTTPServiceUnavailable.new('1.1', '503', 'Unavailable'))
    expect { GachaSimulation::ExchangeRate.refresh }.to raise_error(GachaSimulation::Unavailable)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    allow(response).to receive(:body).and_return({ date: Date.today.iso8601, rate: 150 }.to_json)
    expect(http).to receive(:get).with(uri.request_uri).and_return(response)
    redis = double('redis')
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    expect(redis).to receive(:set).with(GachaSimulation::ExchangeRate::KEY, anything, ex: 8 * 86400)
    expect(GachaSimulation::ExchangeRate.refresh['jpy_per_usd']).to eq('150.0')
  end
end
