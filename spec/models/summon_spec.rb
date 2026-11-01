# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Summon, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:summon_series).optional }
  end

  describe 'validations' do
    it 'is valid from the factory' do
      expect(build(:summon)).to be_valid
      expect(build(:summon, :r)).to be_valid
      expect(build(:summon, :sr)).to be_valid
    end

    it 'requires a unique 10-digit granblue_id' do
      expect(build(:summon, granblue_id: nil)).not_to be_valid
      expect(build(:summon, granblue_id: '204000100')).not_to be_valid
      expect(build(:summon, granblue_id: '2040001000-1')).not_to be_valid
      create(:summon, granblue_id: '2040001000')
      expect(build(:summon, granblue_id: '2040001000')).not_to be_valid
    end

    it 'requires an English name' do
      expect(build(:summon, name_en: ' ')).not_to be_valid
    end

    it 'accepts only known rarities and elements, never Null' do
      expect(build(:summon, rarity: 4)).not_to be_valid
      expect(build(:summon, rarity: nil)).not_to be_valid
      expect(build(:summon, element: 0)).not_to be_valid
      expect(build(:summon, element: 7)).not_to be_valid
      expect(build(:summon, element: 6)).to be_valid
    end

    it 'takes whole, non-negative stats and a max level of at least 1' do
      expect(build(:summon, max_hp_xlb: nil, summon_id: nil)).to be_valid
      expect(build(:summon, min_atk: -1)).not_to be_valid
      expect(build(:summon, max_hp: 1.5)).not_to be_valid
      expect(build(:summon, summon_id: -1)).not_to be_valid
      expect(build(:summon, max_level: 0)).not_to be_valid
    end
  end

  describe 'promotion helpers' do
    let(:flash_value) { GranblueEnums::PROMOTIONS[:Flash] }
    let(:legend_value) { GranblueEnums::PROMOTIONS[:Legend] }
    let(:premium_value) { GranblueEnums::PROMOTIONS[:Premium] }

    describe '#flash?' do
      it 'returns true when promotions include Flash' do
        summon = build(:summon, promotions: [flash_value])
        expect(summon.flash?).to be true
      end

      it 'returns false when promotions do not include Flash' do
        summon = build(:summon, promotions: [legend_value])
        expect(summon.flash?).to be false
      end
    end

    describe '#legend?' do
      it 'returns true when promotions include Legend' do
        summon = build(:summon, promotions: [legend_value])
        expect(summon.legend?).to be true
      end

      it 'returns false when promotions do not include Legend' do
        summon = build(:summon, promotions: [flash_value])
        expect(summon.legend?).to be false
      end
    end

    describe '#premium?' do
      it 'returns true when promotions include Premium' do
        summon = build(:summon, promotions: [premium_value])
        expect(summon.premium?).to be true
      end
    end

    describe '#promotion_names' do
      it 'returns promotion names as strings' do
        summon = build(:summon, promotions: [flash_value, premium_value])
        expect(summon.promotion_names).to contain_exactly('Flash', 'Premium')
      end

      it 'returns empty array when no promotions' do
        summon = build(:summon, promotions: [])
        expect(summon.promotion_names).to eq([])
      end
    end
  end

  describe 'promotion scopes' do
    let(:flash_value) { GranblueEnums::PROMOTIONS[:Flash] }
    let(:legend_value) { GranblueEnums::PROMOTIONS[:Legend] }
    let(:premium_value) { GranblueEnums::PROMOTIONS[:Premium] }

    let!(:flash_summon) { create(:summon, promotions: [flash_value]) }
    let!(:legend_summon) { create(:summon, promotions: [legend_value]) }
    let!(:premium_summon) { create(:summon, promotions: [premium_value]) }

    it '.by_promotion filters by promotion value' do
      expect(Summon.by_promotion(flash_value)).to include(flash_summon)
      expect(Summon.by_promotion(flash_value)).not_to include(legend_summon, premium_summon)
    end

    it '.in_premium returns summons with Premium promotion' do
      expect(Summon.in_premium).to include(premium_summon)
      expect(Summon.in_premium).not_to include(flash_summon, legend_summon)
    end
  end

  describe '#series_slug' do
    it 'returns the summon_series slug' do
      series = create(:summon_series, slug: "test-series-#{SecureRandom.hex(4)}")
      summon = build(:summon, summon_series: series)
      expect(summon.series_slug).to eq(series.slug)
    end

    it 'returns nil when no summon_series' do
      summon = build(:summon, summon_series: nil)
      expect(summon.series_slug).to be_nil
    end
  end

  describe '#series=' do
    it 'assigns summon_series by slug' do
      series = create(:summon_series, slug: "assign-test-#{SecureRandom.hex(4)}")
      summon = build(:summon)
      summon.series = series.slug
      expect(summon.summon_series).to eq(series)
    end

    it 'clears summon_series when given blank value' do
      series = create(:summon_series)
      summon = build(:summon, summon_series: series)
      summon.series = ''
      expect(summon.summon_series).to be_nil
    end
  end
end
