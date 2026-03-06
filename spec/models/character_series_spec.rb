# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSeries, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:character_series_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:characters).through(:character_series_memberships) }
  end

  describe 'validations' do
    subject { build(:character_series) }

    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_jp) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_numericality_of(:order).only_integer }
  end

  describe 'scopes' do
    it '.ordered sorts by order ascending' do
      series_b = create(:character_series, order: 2)
      series_a = create(:character_series, order: 1)
      expect(described_class.ordered).to eq([series_a, series_b])
    end
  end

  describe 'constants' do
    it 'defines slug constants' do
      expect(described_class::GRAND).to eq('grand')
      expect(described_class::ZODIAC).to eq('zodiac')
      expect(described_class::ETERNAL).to eq('eternal')
      expect(described_class::EVOKER).to eq('evoker')
      expect(described_class::SAINT).to eq('saint')
    end
  end
end
