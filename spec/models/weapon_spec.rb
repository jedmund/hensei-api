# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Weapon, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:weapon_awakenings) }
    it { is_expected.to have_many(:awakenings).through(:weapon_awakenings) }
    it { is_expected.to have_many(:weapon_skills) }
    it { is_expected.to have_many(:skills).through(:weapon_skills) }
    it { is_expected.to belong_to(:weapon_series).optional }
  end

  describe '#compatible_with_key?' do
    let(:opus_series) { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus) }
    let(:gacha_series) { WeaponSeries.find_by(slug: 'gacha') || create(:weapon_series, :gacha) }
    let(:weapon_key) { create(:weapon_key) }

    before do
      create(:weapon_key_series, weapon_key: weapon_key, weapon_series: opus_series)
    end

    it 'returns true when the key is compatible with the weapon series' do
      weapon = create(:weapon, weapon_series: opus_series)
      expect(weapon.compatible_with_key?(weapon_key)).to be true
    end

    it 'returns false when the key is incompatible' do
      weapon = create(:weapon, weapon_series: gacha_series)
      expect(weapon.compatible_with_key?(weapon_key)).to be false
    end

    it 'returns false when the weapon has no series' do
      weapon = create(:weapon, weapon_series: nil)
      expect(weapon.compatible_with_key?(weapon_key)).to be false
    end
  end

  describe '#opus_or_draconic?' do
    it 'returns true for dark opus weapons' do
      opus_series = WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus)
      weapon = build(:weapon, weapon_series: opus_series)
      expect(weapon.opus_or_draconic?).to be true
    end

    it 'returns true for draconic weapons' do
      draconic_series = WeaponSeries.find_by(slug: 'draconic') || create(:weapon_series, :draconic)
      weapon = build(:weapon, weapon_series: draconic_series)
      expect(weapon.opus_or_draconic?).to be true
    end

    it 'returns false for other series' do
      gacha_series = WeaponSeries.find_by(slug: 'gacha') || create(:weapon_series, :gacha)
      weapon = build(:weapon, weapon_series: gacha_series)
      expect(weapon.opus_or_draconic?).to be false
    end

    it 'returns false when no weapon_series' do
      weapon = build(:weapon, weapon_series: nil)
      expect(weapon.opus_or_draconic?).to be false
    end
  end

  describe '#draconic_or_providence?' do
    it 'returns true for draconic weapons' do
      draconic_series = WeaponSeries.find_by(slug: 'draconic') || create(:weapon_series, :draconic)
      weapon = build(:weapon, weapon_series: draconic_series)
      expect(weapon.draconic_or_providence?).to be true
    end

    it 'returns true for draconic providence weapons' do
      dp_series = WeaponSeries.find_by(slug: 'draconic-providence') || create(:weapon_series, :draconic_providence)
      weapon = build(:weapon, weapon_series: dp_series)
      expect(weapon.draconic_or_providence?).to be true
    end

    it 'returns false for other series' do
      opus_series = WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus)
      weapon = build(:weapon, weapon_series: opus_series)
      expect(weapon.draconic_or_providence?).to be false
    end
  end

  describe '.element_changeable?' do
    it 'returns true for a weapon with an element-changeable series' do
      series = create(:weapon_series, :element_changeable)
      weapon = create(:weapon, weapon_series: series)
      expect(described_class.element_changeable?(weapon)).to be true
    end

    it 'returns false for a weapon without an element-changeable series' do
      series = create(:weapon_series, element_changeable: false)
      weapon = create(:weapon, weapon_series: series)
      expect(described_class.element_changeable?(weapon)).to be false
    end

    it 'accepts a WeaponSeries directly' do
      series = create(:weapon_series, :element_changeable)
      expect(described_class.element_changeable?(series)).to be true
    end

    it 'returns false for unknown types' do
      expect(described_class.element_changeable?('string')).to be false
    end
  end

  describe 'promotion helpers' do
    let(:flash_value) { GranblueEnums::PROMOTIONS[:Flash] }
    let(:legend_value) { GranblueEnums::PROMOTIONS[:Legend] }
    let(:premium_value) { GranblueEnums::PROMOTIONS[:Premium] }

    describe '#flash?' do
      it 'returns true when promotions include Flash' do
        weapon = build(:weapon, promotions: [flash_value])
        expect(weapon.flash?).to be true
      end

      it 'returns false when promotions do not include Flash' do
        weapon = build(:weapon, promotions: [])
        expect(weapon.flash?).to be false
      end
    end

    describe '#legend?' do
      it 'returns true when promotions include Legend' do
        weapon = build(:weapon, promotions: [legend_value])
        expect(weapon.legend?).to be true
      end
    end

    describe '#premium?' do
      it 'returns true when promotions include Premium' do
        weapon = build(:weapon, promotions: [premium_value])
        expect(weapon.premium?).to be true
      end
    end

    describe '#promotion_names' do
      it 'returns promotion names as strings' do
        weapon = build(:weapon, promotions: [flash_value, premium_value])
        expect(weapon.promotion_names).to contain_exactly('Flash', 'Premium')
      end

      it 'returns empty array when no promotions' do
        weapon = build(:weapon, promotions: [])
        expect(weapon.promotion_names).to eq([])
      end
    end
  end

  describe '#series_slug' do
    it 'returns the weapon_series slug' do
      series = create(:weapon_series, slug: "test-slug-#{SecureRandom.hex(4)}")
      weapon = build(:weapon, weapon_series: series)
      expect(weapon.series_slug).to eq(series.slug)
    end

    it 'returns nil when no weapon_series' do
      weapon = build(:weapon, weapon_series: nil)
      expect(weapon.series_slug).to be_nil
    end
  end

  describe '#series=' do
    it 'assigns weapon_series by slug' do
      series = create(:weapon_series, slug: "assign-#{SecureRandom.hex(4)}")
      weapon = build(:weapon)
      weapon.series = series.slug
      expect(weapon.weapon_series).to eq(series)
    end

    it 'clears weapon_series when given blank value' do
      series = create(:weapon_series)
      weapon = build(:weapon, weapon_series: series)
      weapon.series = ''
      expect(weapon.weapon_series).to be_nil
    end
  end

  describe 'promotion scopes' do
    let(:flash_value) { GranblueEnums::PROMOTIONS[:Flash] }
    let(:legend_value) { GranblueEnums::PROMOTIONS[:Legend] }
    let(:premium_value) { GranblueEnums::PROMOTIONS[:Premium] }

    let!(:flash_weapon) { create(:weapon, promotions: [flash_value]) }
    let!(:legend_weapon) { create(:weapon, promotions: [legend_value]) }
    let!(:premium_weapon) { create(:weapon, promotions: [premium_value]) }
    let!(:flash_and_legend_weapon) { create(:weapon, promotions: [flash_value, legend_value]) }

    it '.by_promotion filters by promotion value' do
      expect(Weapon.by_promotion(flash_value)).to include(flash_weapon, flash_and_legend_weapon)
      expect(Weapon.by_promotion(flash_value)).not_to include(legend_weapon, premium_weapon)
    end

    it '.in_premium returns weapons with Premium promotion' do
      expect(Weapon.in_premium).to include(premium_weapon)
      expect(Weapon.in_premium).not_to include(flash_weapon, legend_weapon)
    end

    it '.flash_exclusive returns flash weapons that are NOT legend' do
      expect(Weapon.flash_exclusive).to include(flash_weapon)
      expect(Weapon.flash_exclusive).not_to include(flash_and_legend_weapon)
    end
  end

  describe 'forge chain' do
    describe '#compute_forge_chain_fields' do
      it 'auto-computes forge_chain_id and forge_order on save' do
        base = create(:weapon, granblue_id: 'chain_base')
        forged = create(:weapon, granblue_id: 'chain_child', forged_from: 'chain_base')

        forged.reload
        expect(forged.forge_chain_id).to eq(base.id)
        expect(forged.forge_order).to eq(1)

        base.reload
        expect(base.forge_chain_id).to eq(base.id)
        expect(base.forge_order).to eq(0)
      end
    end

    describe '#no_circular_forge_chain' do
      it 'allows a valid forge chain' do
        create(:weapon, granblue_id: 'forge_base_1')
        forged = build(:weapon, granblue_id: 'forge_child_1', forged_from: 'forge_base_1')
        expect(forged).to be_valid
      end

      it 'rejects a circular forge chain' do
        weapon_a = create(:weapon, granblue_id: 'circular_a', forged_from: nil)
        create(:weapon, granblue_id: 'circular_b', forged_from: 'circular_a')
        weapon_a.forged_from = 'circular_b'
        expect(weapon_a).not_to be_valid
        expect(weapon_a.errors[:forged_from]).to include('creates a circular forge chain')
      end
    end

    describe '#forged_from_weapon' do
      it 'returns the weapon it was forged from' do
        base = create(:weapon, granblue_id: 'from_base_1')
        forged = create(:weapon, forged_from: 'from_base_1')
        expect(forged.forged_from_weapon).to eq(base)
      end

      it 'returns nil when forged_from is blank' do
        weapon = build(:weapon, forged_from: nil)
        expect(weapon.forged_from_weapon).to be_nil
      end
    end
  end
end
