# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSeries, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:weapons).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:weapon_key_series).dependent(:destroy) }
    it { is_expected.to have_many(:weapon_keys).through(:weapon_key_series) }
  end

  describe 'validations' do
    subject { build(:weapon_series) }

    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_jp) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_numericality_of(:order).only_integer }
  end

  describe 'enums' do
    it 'defines augment_type enum' do
      expect(described_class.augment_types).to eq(
        'no_augment' => 0,
        'ax' => 1,
        'befoulment' => 2
      )
    end

    it 'defaults to no_augment' do
      series = build(:weapon_series)
      expect(series.augment_type).to eq('no_augment')
    end
  end

  describe 'scopes' do
    it '.ordered sorts by order ascending' do
      series_b = create(:weapon_series, order: 9998)
      series_a = create(:weapon_series, order: 9997)
      ordered = described_class.ordered
      expect(ordered.index(series_a)).to be < ordered.index(series_b)
    end

    it '.extra_allowed returns series where extra is true' do
      extra = create(:weapon_series, :extra_allowed)
      normal = create(:weapon_series, extra: false)
      expect(described_class.extra_allowed).to include(extra)
      expect(described_class.extra_allowed).not_to include(normal)
    end

    it '.element_changeable returns series where element_changeable is true' do
      changeable = create(:weapon_series, :element_changeable)
      fixed = create(:weapon_series, element_changeable: false)
      expect(described_class.element_changeable).to include(changeable)
      expect(described_class.element_changeable).not_to include(fixed)
    end

    it '.with_weapon_keys returns series that have weapon keys' do
      with_keys = create(:weapon_series, :with_weapon_keys)
      without_keys = create(:weapon_series, has_weapon_keys: false)
      expect(described_class.with_weapon_keys).to include(with_keys)
      expect(described_class.with_weapon_keys).not_to include(without_keys)
    end

    it '.with_awakening returns series that have awakenings' do
      with_awk = create(:weapon_series, has_awakening: true)
      without_awk = create(:weapon_series, has_awakening: false)
      expect(described_class.with_awakening).to include(with_awk)
      expect(described_class.with_awakening).not_to include(without_awk)
    end

    it '.with_ax_skills returns series with ax augment type' do
      ax_series = create(:weapon_series, :with_ax_skills)
      normal = create(:weapon_series)
      expect(described_class.with_ax_skills).to include(ax_series)
      expect(described_class.with_ax_skills).not_to include(normal)
    end

    it '.with_befoulments returns series with befoulment augment type' do
      befoul = create(:weapon_series, :with_befoulments)
      normal = create(:weapon_series)
      expect(described_class.with_befoulments).to include(befoul)
      expect(described_class.with_befoulments).not_to include(normal)
    end
  end

  describe 'constants' do
    it 'defines slug constants' do
      expect(described_class::DARK_OPUS).to eq('dark-opus')
      expect(described_class::DRACONIC).to eq('draconic')
      expect(described_class::DRACONIC_PROVIDENCE).to eq('draconic-providence')
      expect(described_class::REVENANT).to eq('revenant')
      expect(described_class::ULTIMA).to eq('ultima')
      expect(described_class::SUPERLATIVE).to eq('superlative')
      expect(described_class::CLASS_CHAMPION).to eq('class-champion')
    end
  end
end
