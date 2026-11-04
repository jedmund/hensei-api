require 'rails_helper'

# Pins the exact compiled pools and seeded results, so a refactor that changes a
# probability or the order of random draws shows up as a different digest.
RSpec.describe 'Gacha simulation seeded results' do
  let(:evidence) { JSON.parse(Rails.root.join('spec/fixtures/gacha/user-banner-rates.json').read) }
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
  let(:snapshot) { { 'items' => items, 'fingerprint' => 'fixture', 'loaded_at' => 0 } }
  let(:featured) do
    ids = %w[1040221700 1040320500]
    items.select { |item| ids.include?(item['granblue_id']) }
  end
  let(:rateups) { featured.map { |item| { 'identity' => item['identity'], 'percent' => '0.3' } } }

  before { allow(GachaSimulation::ExchangeRate).to receive(:quote).and_return(nil) }

  def compile(input)
    GachaSimulation::Compiler.new(snapshot, GachaSimulation::Configuration.normalize(input)).compile
  end

  def digest(value)
    Digest::SHA256.hexdigest(JSON.generate(value))
  end

  def draw_digests(compiled, count)
    result = GachaSimulation::Engine.new(compiled, 'seed').draw(count)
    { totals: result['totals'], ordered: result['ordered'] && digest(result['ordered'].pluck('identity')),
      ssr_order: digest(result['ssr_order']), items: digest(result['items']) }
  end

  describe 'a legend pool with rate-ups' do
    let(:compiled) { compile('mode' => 'legend', 'rateups' => rateups) }

    it 'compiles the same pool' do
      expect(compiled['ordinary'].size).to eq(571)
      expect(compiled['guaranteed'].size).to eq(571)
      expect(digest(compiled.slice('ordinary', 'guaranteed')))
        .to eq('a262e5ea56557eb7e1ef9f4860b7fff23579a96eaba4d2e0e262463495ad0d5f')
    end

    it 'draws the same 300 items for a seed' do
      expect(draw_digests(compiled, 300)).to eq(
        totals: { 'R' => '210', 'SR' => '67', 'SSR' => '23' },
        ordered: '249d98838e8d79b136224440af96df04e8a2034e38d719159173f2d1fb47152a',
        ssr_order: '6b124a48c7bc60de571eb47d6867797de28c2197144c2242eaf803bc90dc88ea',
        items: '3612f92671bce9fd11f8e19d46ecc14e0dc72cdd9d0949dae81d8842aaa29fa7'
      )
    end

    it 'draws the same 2000 items for a seed, without the full order' do
      expect(draw_digests(compiled, 2000)).to eq(
        totals: { 'R' => '1414', 'SR' => '447', 'SSR' => '139' }, ordered: nil,
        ssr_order: 'abaec05cc141370448e87546b1a5f3f303b98687864ffedc44262b95e66ba937',
        items: 'a30e21914199c261a2daf9290a4374bf01e0c3a57a11dc1c489ed41a3b3f3eae'
      )
    end

    it 'waits the same number of draws for a seed' do
      result = GachaSimulation::Engine.new(compiled, 'seed').target('until', 'target' => featured.first['identity'], 'copies' => 3)
      expect(result.slice('draws', 'copies', 'requested_copies'))
        .to eq('draws' => '1310', 'copies' => '3', 'requested_copies' => '3')
    end

    it 'gives the same odds and thresholds' do
      engine = GachaSimulation::Engine.new(compiled, 'seed')
      at_least = engine.target('odds', 'target' => featured.first['identity'], 'copies' => 2, 'draws' => 300)
      exactly = engine.target('odds', 'target' => featured.first['identity'], 'copies' => 1, 'draws' => 120,
                                      'comparison' => 'exactly')
      expect(at_least.slice('probability', 'expected_copies', 'thresholds')).to eq(
        'probability' => 0.2274623288190493, 'expected_copies' => 0.9,
        'thresholds' => { '50' => '560', '90' => '1300', '95' => '1580' }
      )
      expect(exactly.slice('probability', 'expected_copies', 'thresholds')).to eq(
        'probability' => 0.2517829628880564, 'expected_copies' => 0.36,
        'thresholds' => { '50' => '240', '90' => '770', '95' => '1000' }
      )
    end
  end

  describe 'a premium pool' do
    let(:compiled) { compile({}) }

    it 'compiles and draws the same' do
      expect(digest(compiled.slice('ordinary', 'guaranteed')))
        .to eq('9e74e27d5eb0717ccdc2c43b2deafe59297fd91baab45623839a49290e17535d')
      expect(draw_digests(compiled, 300)).to eq(
        totals: { 'R' => '216', 'SR' => '72', 'SSR' => '12' },
        ordered: '727c056061078ef536601990f6f27eb0ce3c89bfc10502b9c723b3d6f2c7d397',
        ssr_order: 'dd161a70ff546e338b758e81b0b03c2acc4d9d7f2c3fa46bedddd34683039ee3',
        items: '762401f6fc9be5fbb43225e57c06f6f300cf6c50d85366247e1bd3c96e931fc2'
      )
    end
  end

  describe 'a flash pool bought in singles' do
    let(:compiled) { compile('mode' => 'flash', 'purchase' => 'singles') }

    it 'compiles and draws the same' do
      expect(digest(compiled.slice('ordinary', 'guaranteed')))
        .to eq('db403c1c117284678f16d9539cffe512d3045be9880353e4284a1bd5a210cb10')
      expect(draw_digests(compiled, 2000)).to eq(
        totals: { 'R' => '1569', 'SR' => '292', 'SSR' => '139' }, ordered: nil,
        ssr_order: '5946f34ad2c140ae1e830490651a314ca04d9d422c3463d1b2ad9dd3c4618350',
        items: '961aa5ac870b9b78cab40382799c7bd7216a8019fb895d31c154c522b50acdef'
      )
    end
  end

  describe GachaSimulation::Probability do
    it 'samples the same waits for a seeded generator' do
      expect(described_class.waiting(Random.new(7), 0.003, 0.003, 4, 'ten')).to eq('draws' => '1750', 'copies' => '4')
      expect(described_class.waiting(Random.new(7), 0.003, 0.03, 2, 'ten')).to eq('draws' => '130', 'copies' => '2')
      expect(described_class.waiting(Random.new(7), 0.003, 0.003, 4, 'singles')).to eq('draws' => '1152', 'copies' => '4')
    end

    it 'gives the same odds and thresholds' do
      expect(described_class.odds(300, 0.003, 0.03, 2, 'ten', 'at_least')).to eq(0.5117542148516755)
      expect(described_class.odds(300, 0.003, 0.03, 2, 'ten', 'exactly')).to eq(0.2670302981045656)
      expect(described_class.odds(300, 0.003, 0.03, 2, 'singles', 'at_least')).to eq(0.2274623288190493)
      expect(described_class.threshold(0.003, 0.03, 2, 'ten', 0.5)).to eq('300')
      expect(described_class.threshold(0.003, 0.003, 4, 'singles', 0.95)).to eq('2583')
    end
  end
end
