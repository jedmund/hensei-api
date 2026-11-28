# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedSpark do
  subject(:spark) { build(:saved_spark) }

  it 'is valid with the factory defaults' do
    expect(spark).to be_valid
  end

  it 'is valid when empty' do
    spark.assign_attributes(characters: [], moons: [], summons: [])
    expect(spark).to be_valid
  end

  describe 'spark_date' do
    it 'is required' do
      spark.spark_date = nil
      expect(spark).not_to be_valid
      expect(spark.errors[:spark_date]).to be_present
    end

    it 'allows a day of slack for time zones' do
      spark.spark_date = Date.current + 1
      expect(spark).to be_valid
    end

    it 'rejects dates further in the future' do
      spark.spark_date = Date.current + 2
      expect(spark).not_to be_valid
      expect(spark.errors[:spark_date]).to include('cannot be in the future')
    end

    it 'rejects dates before the game existed' do
      spark.spark_date = Date.new(2014, 3, 9)
      expect(spark).not_to be_valid
    end

    it 'rejects a string that is not a date' do
      spark.spark_date = 'yesterday-ish'
      expect(spark).not_to be_valid
    end
  end

  describe 'draws' do
    it 'accepts the bounds' do
      [1, 99_999].each do |draws|
        spark.draws = draws
        expect(spark).to be_valid
      end
    end

    it 'rejects values outside 1..99999 or not whole' do
      [0, -1, 100_000, 1.5, 'many', nil].each do |draws|
        spark.draws = draws
        expect(spark).not_to be_valid, "expected #{draws.inspect} to be invalid"
      end
    end
  end

  describe 'item ids' do
    it 'rejects summon ids among the characters and moons' do
      spark.characters = %w[2040000000]
      spark.moons = %w[2040000000]
      expect(spark).not_to be_valid
      expect(spark.errors.attribute_names).to include(:characters, :moons)
    end

    it 'rejects weapon ids among the summons' do
      spark.summons = %w[1040000000]
      expect(spark).not_to be_valid
      expect(spark.errors[:summons]).to be_present
    end

    it 'rejects ids of the wrong length or with trailing text' do
      ['104000000', '10400000000', "1040000000\n1", '1o40000000', ''].each do |id|
        spark.characters = [id]
        expect(spark).not_to be_valid, "expected #{id.inspect} to be invalid"
      end
    end

    it 'allows a repeated id (the same SSR twice)' do
      spark.moons = %w[1040000200 1040000200]
      expect(spark).to be_valid
    end

    it 'allows 60 per column but not 61' do
      spark.summons = Array.new(60) { '2040000000' }
      expect(spark).to be_valid

      spark.summons = Array.new(61) { '2040000000' }
      expect(spark).not_to be_valid
      expect(spark.errors[:summons]).to include('can hold at most 60 items')
    end
  end

  describe 'sparked marks' do
    let(:mark) { ->(column, index) { { 'column' => column, 'index' => index } } }

    it 'may be empty' do
      spark.sparked_marks = []
      expect(spark).to be_valid
      expect(spark.sparked).to be_nil
    end

    it 'may point at any item in any column' do
      spark.sparked_marks = [mark.call('summons', 0), mark.call('characters', 1), mark.call('moons', 0)]
      expect(spark).to be_valid
    end

    it 'keeps several marks in column order, each once' do
      spark.sparked_marks = [{ column: 'moons', index: 0 }, mark.call('characters', 1),
                             mark.call('characters', 0), mark.call('moons', 0)]
      expect(spark.sparked_marks).to eq([mark.call('characters', 0), mark.call('characters', 1),
                                         mark.call('moons', 0)])
      expect(spark.sparked).to eq(mark.call('characters', 0))
    end

    it 'must point at an existing item' do
      spark.sparked_marks = [mark.call('moons', 1)]
      expect(spark).not_to be_valid
      expect(spark.errors[:sparked]).to include('must point at an item in its column')

      spark.sparked_marks = [mark.call('moons', -1)]
      expect(spark).not_to be_valid
    end

    it 'needs a known column' do
      spark.sparked_marks = [mark.call('weapons', 0)]
      expect(spark).not_to be_valid
      expect(spark.errors[:sparked]).to include('needs a known column')
    end

    it 'needs an integer index and a list' do
      spark.sparked_marks = [mark.call('moons', nil)]
      expect(spark).not_to be_valid

      spark.sparked_marks = [mark.call('moons', '0')]
      expect(spark).to be_valid

      spark.sparked_marks = 'c1'
      expect(spark).not_to be_valid
    end
  end

  it 'takes a known pool and season' do
    spark.assign_attributes(pool: 'flash', season: 'halloween')
    expect(spark).to be_valid
    spark.pool = 'gala'
    expect(spark).not_to be_valid
    spark.assign_attributes(pool: 'flash', season: 'spring')
    expect(spark).not_to be_valid
  end

  it 'has no season on Classic or Collab pools' do
    spark.assign_attributes(pool: 'classic_ii', season: 'summer')
    expect(spark).not_to be_valid
    expect(spark.errors[:season]).to be_present
    spark.season = nil
    expect(spark).to be_valid
  end

  it 'takes a Classic pool only from the day it opened' do
    { 'classic' => Date.new(2022, 3, 10), 'classic_ii' => Date.new(2024, 3, 10),
      'classic_iii' => Date.new(2026, 3, 10) }.each do |pool, opened|
      spark.assign_attributes(pool: pool, season: nil, spark_date: opened - 1)
      expect(spark).not_to be_valid
      expect(spark.errors[:pool]).to be_present
      spark.spark_date = opened
      expect(spark).to be_valid
    end
  end

  it 'takes other pools on any date' do
    spark.assign_attributes(pool: 'premium', spark_date: Date.new(2015, 1, 1))
    expect(spark).to be_valid
  end

  it 'is deleted with its user' do
    spark.save!
    spark.user.destroy!
    expect(described_class.exists?(spark.id)).to be(false)
  end
end
