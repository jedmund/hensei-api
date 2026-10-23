require 'rails_helper'

RSpec.describe GachaSimulation::Probability do
  it 'pins the requested analytical example' do
    expect(described_class.binomial(300, 0.003, 4, 'exactly')).to be_within(1e-9).of(0.011010468)
    expect(described_class.binomial(300, 0.003, 4, 'at_least')).to be_within(1e-9).of(0.013303125)
  end

  it 'computes guaranteed slots by convolution' do
    probability = described_class.odds(10, 0.1, 0.7, 1, 'ten', 'at_least')
    expect(probability).to be_within(1e-12).of(1 - ((0.9**9) * 0.3))
    expect(described_class.odds(10, 0.0, 1.0, 1, 'ten', 'exactly')).to eq(1)
  end

  it 'retains tiny tails and handles large counts' do
    expect(described_class.binomial(1_000_000_000_000, 1e-12, 1, 'at_least')).to be_within(1e-10).of(1 - Math.exp(-1))
    expect(described_class.binomial(300, 1e-10, 4, 'at_least')).to be > 0
    expect(described_class.binomial(10, 1, 10, 'exactly')).to eq(1)
    expect(described_class.binomial(10, 0, 1, 'at_least')).to eq(0)
  end

  it 'samples without a draw ceiling, preserves overshoot and replays' do
    first = described_class.waiting(Random.new(1), 1e-12, 1e-12, 2, 'ten')
    expect(first['draws'].to_i).to be > 100_000
    expect(first).to eq(described_class.waiting(Random.new(1), 1e-12, 1e-12, 2, 'ten'))
    expect(described_class.waiting(Random.new(1), 1, 1, 1, 'ten')).to eq('draws' => '10', 'copies' => '10')
  end

  it 'finds the first complete purchase meeting each threshold' do
    threshold = described_class.threshold(0.003, 0.003, 4, 'ten', 0.9).to_i
    expect(described_class.binomial(threshold, 0.003, 4, 'at_least')).to be >= 0.9
    expect(described_class.binomial(threshold - 10, 0.003, 4, 'at_least')).to be < 0.9
    expect(described_class.threshold(1e-20, 1e-20, 1, 'singles', 0.5)).to be_nil
  end
end
