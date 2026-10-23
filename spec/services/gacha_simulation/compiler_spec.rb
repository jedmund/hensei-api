require 'rails_helper'

RSpec.describe GachaSimulation::Compiler do
  let(:evidence) { JSON.parse(File.read(Rails.root.join('spec/fixtures/gacha/user-banner-rates.json'))) }
  let(:items) do
    categories = %w[characterWeapon weapon summon]
    evidence['groups'].flat_map do |group|
      group['rewardIds'].map do |id|
        type = group['category'] == 2 ? 'Summon' : 'Weapon'
        promotions = group['ordinaryPercent'] == '0.032' ? [5] : [1]
        { 'identity' => "#{type}:#{format('%036d', id.to_i)}", 'drawable_type' => type,
          'granblue_id' => id, 'rarity' => group['rarity'] - 1,
          'category' => categories[group['category']], 'promotions' => promotions }
      end
    end
  end
  let(:snapshot) { { 'items' => items, 'fingerprint' => 'fixture', 'loaded_at' => Time.now.to_i } }
  let(:config) do
    featured_ids = %w[1040221700 1040320500]
    featured = items.select { |item| featured_ids.include?(item['granblue_id']) }
    rates = featured.map { |item| { 'identity' => item['identity'], 'percent' => '0.3' } }
    GachaSimulation::Configuration.normalize('mode' => 'legend', 'rateups' => rates)
  end

  it 'reproduces every supplied displayed ordinary and guaranteed percentage' do
    result = described_class.new(snapshot, config).compile
    %w[ordinary guaranteed].each do |slot|
      expect(result[slot].sum { |e| BigDecimal(e['probability']) }).to be_within(BigDecimal('1e-24')).of(1)
      result[slot].each do |entry|
        group = evidence['groups'].find { |g| g['rewardIds'].include?(entry['item']['granblue_id']) }
        displayed = group["#{slot}Percent"]
        probability = BigDecimal(entry['probability'])
        expect((probability * 100).truncate(3)).to eq(BigDecimal(displayed || '0'))
      end
    end
  end

  it 'isolates all Classic pools and rejects Classic seasons' do
    %w[classic classic_ii classic_iii].each do |mode|
      pool = items.map { |item| item.merge('promotions' => [GachaSimulation::Configuration::MODES[mode]]) }
      settings = GachaSimulation::Configuration.normalize('mode' => mode)
      result = described_class.new(snapshot.merge('items' => pool + items), settings).compile
      expect(result['ordinary'].all? { |e| e['item']['promotions'].include?(GachaSimulation::Configuration::MODES[mode]) }).to be true
      expect { GachaSimulation::Configuration.normalize('mode' => mode, 'season' => 'formal') }.to raise_error(GachaSimulation::ValidationError)
    end
  end

  it 'includes every season and deduplicates shared Formal identities' do
    GachaSimulation::Configuration::SEASONS.each do |season, id|
      extra = items.first.merge('identity' => 'Weapon:00000000-0000-0000-0000-000000000099', 'promotions' => [id])
      settings = GachaSimulation::Configuration.normalize('season' => season)
      result = described_class.new(snapshot.merge('items' => items + [extra, extra]), settings).compile
      expect(result['ordinary'].count { |e| e['item']['identity'] == extra['identity'] }).to eq(1)
    end
  end

  it 'rejects unavailable, duplicate, non SSR and excessive custom rates' do
    [[config['rateups'].first] * 2, [{ 'identity' => items.last['identity'], 'percent' => '0.3' }],
     [{ 'identity' => items.first['identity'], 'percent' => '7' }]].each do |rates|
      expect do
        settings = GachaSimulation::Configuration.normalize('mode' => 'legend', 'rateups' => rates)
        described_class.new(snapshot, settings).compile
      end.to raise_error(GachaSimulation::ValidationError)
    end
  end

  it 'replays fixed draws and rejects a zero-probability target' do
    allow(GachaSimulation::ExchangeRate).to receive(:quote).and_return(nil)
    compiled = described_class.new(snapshot, config).compile
    first = GachaSimulation::Engine.new(compiled, 'seed').draw(300)
    expect(first).to eq(GachaSimulation::Engine.new(compiled, 'seed').draw(300))
    expect(first['ordered'].size).to eq(300)
    expect(first['totals'].values.sum(&:to_i)).to eq(300)
    expect(first['cost']['jpy']).to eq('94500.0')
    config['rateups'][0]['percent'] = '0'
    compiled = described_class.new(snapshot, config).compile
    expect { GachaSimulation::Engine.new(compiled).target('until', 'target' => config['rateups'][0]['identity']) }.to raise_error(GachaSimulation::ValidationError)
  end
end
