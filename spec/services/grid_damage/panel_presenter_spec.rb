# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::PanelPresenter do
  describe '.display_value' do
    it 'keeps four decimals, the precision the game uses' do
      expect(described_class.display_value('atk', 12.345678)).to eq('12.3457%')
    end

    it 'trims whole percents' do
      expect(described_class.display_value('atk', 20.0)).to eq('20%')
    end

    it 'formats flat counts with separators' do
      expect(described_class.display_value('ca_supp', 100_000.0)).to eq('+100,000')
    end
  end

  describe '.leftover_lines' do
    it 'returns four-decimal values and marks percents as not flat' do
      result = GridDamage::Aggregator::Result.new(boost_type: 'new_boost', total: 1.234567, raw: 1.234567,
                                                  capped: false, source_map: {})
      line = described_class.leftover_lines({ 'new_boost' => result }, []).first

      expect(line).to include(value: 1.2346, display: '1.2346%', flat: false)
    end
  end
end
