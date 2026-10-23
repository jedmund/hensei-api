# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::AugmentStrength do
  describe '.parse' do
    it 'reads a plain effect_value' do
      expect(described_class.parse('7', '+7%')).to eq(7.0)
      expect(described_class.parse('3.5', '+3.5%')).to eq(3.5)
    end

    it 'reads show_value for tier-prefixed effect_values' do
      # Stamina (1600) secondaries as sent by the game: "2_5" displays as +3.
      expect(described_class.parse('2_5', '+3')).to eq(3.0)
      expect(described_class.parse('2_4', '+2')).to eq(2.0)
    end

    it 'falls back to the last segment when a tier-prefixed value has no show_value' do
      expect(described_class.parse('1_3', nil)).to eq(3.0)
    end

    it 'falls back to show_value when effect_value is missing' do
      expect(described_class.parse(nil, '+3%')).to eq(3.0)
    end

    it 'keeps the sign of a negative show_value' do
      expect(described_class.parse(nil, '-5%')).to eq(-5.0)
    end

    it 'returns nil when neither value is present' do
      expect(described_class.parse(nil, nil)).to be_nil
    end
  end
end
