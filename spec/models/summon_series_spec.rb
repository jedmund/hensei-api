# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonSeries, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:summons).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:summon_series) }

    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_jp) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_numericality_of(:order).only_integer }
  end

  describe 'scopes' do
    it '.ordered sorts by order ascending' do
      series_b = create(:summon_series, order: 2)
      series_a = create(:summon_series, order: 1)
      expect(described_class.ordered).to eq([series_a, series_b])
    end
  end

  describe 'constants' do
    it 'defines slug constants' do
      expect(described_class::PROVIDENCE).to eq('providence')
      expect(described_class::GENESIS).to eq('genesis')
      expect(described_class::MAGNA).to eq('magna')
      expect(described_class::OPTIMUS).to eq('optimus')
      expect(described_class::ARCARUM).to eq('arcarum')
    end
  end
end
