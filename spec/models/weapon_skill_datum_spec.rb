# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkillDatum, type: :model do
  describe 'validations' do
    subject { build(:weapon_skill_datum) }

    it { is_expected.to validate_presence_of(:modifier) }
    it { is_expected.to validate_presence_of(:boost_type) }
    it { is_expected.to validate_presence_of(:size) }
    it { is_expected.to validate_presence_of(:formula_type) }

    context 'series validation' do
      it 'allows nil series' do
        datum = build(:weapon_skill_datum, series: nil)
        expect(datum).to be_valid
      end

      described_class::SERIES_VALUES.each do |value|
        it "allows series '#{value}'" do
          datum = build(:weapon_skill_datum, series: value)
          expect(datum).to be_valid
        end
      end

      it 'rejects invalid series' do
        datum = build(:weapon_skill_datum, series: 'invalid')
        expect(datum).not_to be_valid
      end
    end

    context 'size validation' do
      described_class::SIZE_VALUES.each do |value|
        it "allows size '#{value}'" do
          datum = build(:weapon_skill_datum, size: value)
          expect(datum).to be_valid
        end
      end

      it 'rejects invalid size' do
        datum = build(:weapon_skill_datum, size: 'invalid')
        expect(datum).not_to be_valid
      end

      it 'does not allow nil size' do
        datum = build(:weapon_skill_datum, size: nil)
        expect(datum).not_to be_valid
      end
    end

    context 'formula_type validation' do
      described_class::FORMULA_TYPES.each do |value|
        it "allows formula_type '#{value}'" do
          datum = build(:weapon_skill_datum, formula_type: value)
          expect(datum).to be_valid
        end
      end

      it 'rejects invalid formula_type' do
        datum = build(:weapon_skill_datum, formula_type: 'invalid')
        expect(datum).not_to be_valid
      end
    end

    context 'uniqueness' do
      it 'validates uniqueness of modifier scoped to [boost_type, series, size]' do
        create(:weapon_skill_datum, modifier: 'UniqueMod', boost_type: 'atk', series: 'normal', size: 'big')
        duplicate = build(:weapon_skill_datum, modifier: 'UniqueMod', boost_type: 'atk', series: 'normal', size: 'big')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:modifier]).to include('has already been taken')
      end

      it 'allows same modifier with different boost_type' do
        create(:weapon_skill_datum, modifier: 'UniqueMod2', boost_type: 'atk', series: 'normal', size: 'big')
        different = build(:weapon_skill_datum, modifier: 'UniqueMod2', boost_type: 'hp', series: 'normal', size: 'big')
        expect(different).to be_valid
      end

      it 'allows same modifier with different series' do
        create(:weapon_skill_datum, modifier: 'UniqueMod3', boost_type: 'atk', series: 'normal', size: 'big')
        different = build(:weapon_skill_datum, modifier: 'UniqueMod3', boost_type: 'atk', series: 'omega', size: 'big')
        expect(different).to be_valid
      end

      it 'allows same modifier with different size' do
        create(:weapon_skill_datum, modifier: 'UniqueMod4', boost_type: 'atk', series: 'normal', size: 'big')
        different = build(:weapon_skill_datum, modifier: 'UniqueMod4', boost_type: 'atk', series: 'normal', size: 'small')
        expect(different).to be_valid
      end
    end
  end

  describe '.for_skill' do
    context 'modifier-only lookup (no series, no size)' do
      let!(:datum) { create(:weapon_skill_datum, modifier: 'SephiraMod', series: nil, size: 'big') }

      it 'returns records matching the modifier' do
        results = described_class.for_skill(modifier: 'SephiraMod')
        expect(results).to include(datum)
      end

      it 'returns empty when modifier not found' do
        results = described_class.for_skill(modifier: 'NonExistent')
        expect(results).to be_empty
      end
    end

    context 'with series filter' do
      let!(:normal_datum) { create(:weapon_skill_datum, modifier: 'SeriesMod', series: 'normal', size: 'big') }
      let!(:omega_datum) { create(:weapon_skill_datum, modifier: 'SeriesMod', series: 'omega', size: 'big') }

      it 'filters by series' do
        results = described_class.for_skill(modifier: 'SeriesMod', series: 'normal')
        expect(results).to include(normal_datum)
        expect(results).not_to include(omega_datum)
      end
    end

    context 'with size filter' do
      let!(:big_datum) { create(:weapon_skill_datum, modifier: 'SizeMod', series: 'normal', size: 'big') }
      let!(:small_datum) { create(:weapon_skill_datum, modifier: 'SizeMod', series: 'normal', size: 'small') }

      it 'filters by size' do
        results = described_class.for_skill(modifier: 'SizeMod', series: 'normal', size: 'big')
        expect(results).to include(big_datum)
        expect(results).not_to include(small_datum)
      end
    end

    context 'normal → normal_omega fallback' do
      let!(:normal_omega_datum) do
        create(:weapon_skill_datum, modifier: 'FallbackMod', series: 'normal_omega', size: 'big')
      end

      it 'falls back to normal_omega when no direct normal match' do
        results = described_class.for_skill(modifier: 'FallbackMod', series: 'normal', size: 'big')
        expect(results).to include(normal_omega_datum)
      end

      it 'does NOT fall back when direct normal match exists' do
        direct = create(:weapon_skill_datum, modifier: 'FallbackMod', series: 'normal', size: 'big',
                                             boost_type: 'hp')
        results = described_class.for_skill(modifier: 'FallbackMod', series: 'normal', size: 'big')
        expect(results).to include(direct)
        expect(results).not_to include(normal_omega_datum)
      end

      it 'applies size filter to the fallback query' do
        results = described_class.for_skill(modifier: 'FallbackMod', series: 'normal', size: 'small')
        expect(results).to be_empty
      end
    end

    context 'omega → normal_omega fallback' do
      let!(:normal_omega_datum) do
        create(:weapon_skill_datum, modifier: 'OmegaFB', series: 'normal_omega', size: 'big')
      end

      it 'falls back to normal_omega when no direct omega match' do
        results = described_class.for_skill(modifier: 'OmegaFB', series: 'omega', size: 'big')
        expect(results).to include(normal_omega_datum)
      end
    end

    context 'no fallback for ex series' do
      let!(:normal_omega_datum) do
        create(:weapon_skill_datum, modifier: 'ExNoFB', series: 'normal_omega', size: 'big')
      end

      it 'returns empty and does NOT fall back to normal_omega' do
        results = described_class.for_skill(modifier: 'ExNoFB', series: 'ex', size: 'big')
        expect(results).to be_empty
      end
    end

    context 'no fallback for odious series' do
      let!(:normal_omega_datum) do
        create(:weapon_skill_datum, modifier: 'OdiousNoFB', series: 'normal_omega', size: 'big')
      end

      it 'returns empty and does NOT fall back to normal_omega' do
        results = described_class.for_skill(modifier: 'OdiousNoFB', series: 'odious', size: 'big')
        expect(results).to be_empty
      end
    end

    context 'no fallback for nil series' do
      let!(:normal_omega_datum) do
        create(:weapon_skill_datum, modifier: 'NilNoFB', series: 'normal_omega', size: 'big')
      end
      let!(:nil_datum) do
        create(:weapon_skill_datum, modifier: 'NilNoFB', series: nil, size: 'big')
      end

      it 'returns the nil-series record without falling back' do
        results = described_class.for_skill(modifier: 'NilNoFB')
        expect(results).to include(nil_datum)
        expect(results).to include(normal_omega_datum)
      end
    end
  end
end
