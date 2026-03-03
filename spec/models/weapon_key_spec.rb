# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponKey, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:weapon_key_series).dependent(:destroy) }
    it { is_expected.to have_many(:weapon_series).through(:weapon_key_series) }
  end

  describe '#compatible_with_weapon?' do
    let(:opus_series) { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus) }
    let(:gacha_series) { WeaponSeries.find_by(slug: 'gacha') || create(:weapon_series, :gacha) }
    let(:weapon_key) { create(:weapon_key) }

    before do
      create(:weapon_key_series, weapon_key: weapon_key, weapon_series: opus_series)
    end

    it 'returns true when the weapon belongs to a compatible series' do
      weapon = create(:weapon, weapon_series: opus_series)
      expect(weapon_key.compatible_with_weapon?(weapon)).to be true
    end

    it 'returns false when the weapon belongs to an incompatible series' do
      weapon = create(:weapon, weapon_series: gacha_series)
      expect(weapon_key.compatible_with_weapon?(weapon)).to be false
    end

    it 'returns false when the weapon has no weapon_series' do
      weapon = create(:weapon, weapon_series: nil)
      expect(weapon_key.compatible_with_weapon?(weapon)).to be false
    end
  end
end
