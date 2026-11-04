require 'rails_helper'

RSpec.describe GachaSimulation::Configuration do
  let(:first) { 'Weapon:00000000-0000-0000-0000-000000000002' }
  let(:second) { 'Summon:00000000-0000-0000-0000-000000000001' }

  describe '.normalize' do
    it 'fills in the defaults' do
      expect(described_class.normalize({}))
        .to eq('mode' => 'premium', 'season' => nil, 'purchase' => 'ten', 'rateups' => [])
    end

    it 'sorts rate-ups by identity and writes their percentages as plain decimals' do
      input = { 'mode' => 'legend', 'season' => 'summer', 'purchase' => 'singles',
                'rateups' => [{ 'identity' => first, 'percent' => '3e-1' }, { 'identity' => second, 'percent' => '0.25' }] }
      expect(described_class.normalize(input)).to eq(
        'mode' => 'legend', 'season' => 'summer', 'purchase' => 'singles',
        'rateups' => [{ 'identity' => second, 'percent' => '0.25' }, { 'identity' => first, 'percent' => '0.3' }]
      )
    end

    it 'keeps the requested current banner' do
      expect(described_class.normalize('mode' => 'current', 'banner' => 211_960))
        .to eq('mode' => 'current', 'season' => nil, 'purchase' => 'ten', 'rateups' => [], 'banner' => '211960')
      expect(described_class.normalize('mode' => 'current', 'season' => '')['banner']).to be_nil
    end

    {
      { 'mode' => 'gala' } => 'Unsupported mode',
      { 'season' => 'spring' } => 'Unsupported season',
      { 'mode' => 'classic_ii', 'season' => 'summer' } => 'Classic pools do not support seasons',
      { 'purchase' => 'thirty' } => 'Purchase must be singles or ten',
      { 'rateups' => {} } => 'Rate-ups must be an array of at most 1000 entries',
      { 'rateups' => Array.new(1001) { {} } } => 'Rate-ups must be an array of at most 1000 entries',
      { 'rateups' => ['x'] } => 'Invalid rate-up',
      { 'rateups' => [{ 'percent' => '-1' }] } => 'Use a finite decimal percentage',
      { 'rateups' => [{ 'percent' => '1e9999' }] } => 'Use a finite decimal percentage',
      { 'rateups' => [{ 'percent' => '101' }] } => 'Percentages must be finite and nonnegative',
      { 'rateups' => [{ 'percent' => '1e-999' }] } => 'Percentage too small to represent',
      { 'rateups' => [{ 'identity' => 'Weapon:1', 'percent' => '1' }] } => 'Use a typed Weapon:UUID or Summon:UUID identity',
      { 'mode' => 'current', 'season' => 'summer' } => 'The current banner has no seasons',
      { 'mode' => 'current', 'banner' => '12a' } => 'Invalid banner id'
    }.each do |input, message|
      it "rejects #{input.inspect.truncate(80)} with \"#{message}\"" do
        expect { described_class.normalize(input) }.to raise_error(GachaSimulation::ValidationError, message)
      end
    end

    it 'rejects duplicate identities and custom rates on the current banner' do
      duplicate = [{ 'identity' => first, 'percent' => '1' }, { 'identity' => first, 'percent' => '2' }]
      expect { described_class.normalize('rateups' => duplicate) }
        .to raise_error(GachaSimulation::ValidationError, 'Duplicate rate-up identity')
      expect { described_class.normalize('mode' => 'current', 'rateups' => duplicate.first(1)) }
        .to raise_error(GachaSimulation::ValidationError, "The current banner's rates come from the game")
    end
  end
end
