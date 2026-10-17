# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Schedule::Normalization do
  describe 'boss and advantage elements' do
    pairs = {
      'Water' => 'Earth', 'Fire' => 'Water', 'Earth' => 'Wind',
      'Wind' => 'Fire', 'Light' => 'Dark', 'Dark' => 'Light'
    }

    pairs.each do |boss, advantage|
      it "maps a #{boss} boss to #{advantage} teams and back" do
        expect(described_class.advantage_for(boss)).to eq(advantage)
        expect(described_class.boss_for(advantage)).to eq(boss)
      end
    end

    it 'covers every element except Null' do
      expect(described_class::ADVANTAGE_BY_BOSS.keys).to match_array(described_class::ELEMENT_NAMES)
    end

    it 'passes nil and unknown values through as nil' do
      expect(described_class.advantage_for(nil)).to be_nil
      expect(described_class.boss_for('Plasma')).to be_nil
    end
  end

  describe '.element_name' do
    it 'normalizes case and whitespace and rejects anything else' do
      expect(described_class.element_name(' fire ')).to eq('Fire')
      expect(described_class.element_name('Null')).to be_nil
      expect(described_class.element_name('')).to be_nil
    end
  end
end
