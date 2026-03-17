# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSeriesVariant, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:weapon_series) }
    it { is_expected.to have_many(:weapons).dependent(:restrict_with_error) }
  end

  describe 'augment_type enum' do
    let(:series) { create(:weapon_series) }

    it 'supports no_augment, ax, and befoulment' do
      variant = create(:weapon_series_variant, weapon_series: series, augment_type: :ax)
      expect(variant).to be_augment_type_ax
    end
  end

  describe 'nullable overrides' do
    let(:series) { create(:weapon_series, has_weapon_keys: true, has_awakening: false) }

    it 'allows all capability columns to be nil' do
      variant = create(:weapon_series_variant, weapon_series: series)
      expect(variant.has_weapon_keys).to be_nil
      expect(variant.has_awakening).to be_nil
      expect(variant.num_weapon_keys).to be_nil
      expect(variant.augment_type).to be_nil
      expect(variant.element_changeable).to be_nil
      expect(variant.extra).to be_nil
    end
  end
end
