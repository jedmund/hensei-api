require 'rails_helper'

RSpec.describe CollectionWeapon, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:weapon) }
    it { should belong_to(:awakening).optional }
    it { should belong_to(:weapon_key1).class_name('WeaponKey').optional }
    it { should belong_to(:weapon_key2).class_name('WeaponKey').optional }
    it { should belong_to(:weapon_key3).class_name('WeaponKey').optional }
    it { should belong_to(:weapon_key4).class_name('WeaponKey').optional }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:weapon) { create(:weapon) }

    subject { build(:collection_weapon, user: user, weapon: weapon) }

    describe 'basic validations' do
      it { should validate_inclusion_of(:uncap_level).in_range(0..5) }
      it { should validate_inclusion_of(:transcendence_step).in_range(0..10) }
      it { should validate_inclusion_of(:awakening_level).in_range(1..10) }
    end

    describe 'transcendence validations' do
      context 'when transcendence_step > 0 with uncap_level < 5' do
        it 'is invalid' do
          collection_weapon = build(:collection_weapon, uncap_level: 4, transcendence_step: 1)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:transcendence_step]).to include('requires uncap level 5 (current: 4)')
        end
      end

      context 'when transcendence_step > 0 with uncap_level = 5' do
        it 'is valid for transcendable weapon' do
          transcendable_weapon = create(:weapon, :transcendable)
          collection_weapon = build(:collection_weapon, weapon: transcendable_weapon, uncap_level: 5, transcendence_step: 5)
          expect(collection_weapon).to be_valid
        end

        it 'is invalid for non-transcendable weapon' do
          non_transcendable_weapon = create(:weapon, transcendence: false)
          collection_weapon = build(:collection_weapon, weapon: non_transcendable_weapon, uncap_level: 5, transcendence_step: 5)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:transcendence_step]).to include('not available for this weapon')
        end
      end
    end

    describe 'awakening validations' do
      context 'when awakening is for wrong object type' do
        it 'is invalid' do
          char_awakening = create(:awakening, object_type: 'Character')
          collection_weapon = build(:collection_weapon, awakening: char_awakening)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:awakening]).to include('must be a weapon awakening')
        end
      end

      context 'when awakening is for correct object type' do
        it 'is valid' do
          weapon_awakening = create(:awakening, object_type: 'Weapon')
          collection_weapon = build(:collection_weapon, awakening: weapon_awakening)
          expect(collection_weapon).to be_valid
        end
      end

      context 'when awakening_level > 1 without awakening' do
        it 'is invalid' do
          collection_weapon = build(:collection_weapon, awakening: nil, awakening_level: 5)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:awakening_level]).to include('cannot be set without an awakening')
        end
      end
    end

    describe 'AX skill validations' do
      let(:ax_modifier) do
        WeaponStatModifier.find_by(slug: 'ax_atk') ||
          create(:weapon_stat_modifier, :ax_atk)
      end

      context 'when AX skill has only modifier' do
        it 'is invalid' do
          collection_weapon = build(:collection_weapon, ax_modifier1: ax_modifier, ax_strength1: nil)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:base]).to include('AX skill 1 must have both modifier and strength')
        end
      end

      context 'when AX skill has only strength' do
        it 'is invalid' do
          collection_weapon = build(:collection_weapon, ax_modifier2: nil, ax_strength2: 10.5)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:base]).to include('AX skill 2 must have both modifier and strength')
        end
      end

      context 'when AX skill has both modifier and strength' do
        it 'is valid' do
          collection_weapon = build(:collection_weapon, ax_modifier1: ax_modifier, ax_strength1: 3.5)
          expect(collection_weapon).to be_valid
        end
      end
    end

    describe 'weapon key validations' do
      let(:opus_weapon) { create(:weapon, :opus) }
      let(:draconic_weapon) { create(:weapon, :draconic) }
      let(:regular_weapon) { create(:weapon) }

      context 'when weapon_key4 is set on non-Opus/Draconic weapon' do
        it 'is invalid' do
          key = create(:weapon_key)
          collection_weapon = build(:collection_weapon, weapon: regular_weapon, weapon_key4: key)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:weapon_key4]).to include('can only be set on Opus or Draconic weapons')
        end
      end

      context 'when weapon_key4 is set on Opus weapon' do
        it 'is valid' do
          key = create(:weapon_key, :opus_key)
          collection_weapon = build(:collection_weapon, weapon: opus_weapon, weapon_key4: key)
          expect(collection_weapon).to be_valid
        end
      end
    end

    describe 'element change validations' do
      context 'when element is set on non-element-changeable weapon' do
        it 'is invalid' do
          collection_weapon = build(:collection_weapon, element: 1)
          expect(collection_weapon).not_to be_valid
          expect(collection_weapon.errors[:element]).to include('can only be set on element-changeable weapons')
        end
      end

      context 'when element is set on Revenant weapon' do
        let(:revenant_weapon) { create(:weapon, :revenant) }

        it 'is valid' do
          collection_weapon = build(:collection_weapon, weapon: revenant_weapon, element: 2)
          expect(collection_weapon).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let!(:fire_weapon) { create(:weapon, element: 0) }
    let!(:water_weapon) { create(:weapon, element: 1) }
    let!(:ssr_weapon) { create(:weapon, rarity: 4) }
    let!(:sr_weapon) { create(:weapon, rarity: 3) }

    let!(:fire_collection) { create(:collection_weapon, weapon: fire_weapon) }
    let!(:water_collection) { create(:collection_weapon, weapon: water_weapon) }
    let!(:ssr_collection) { create(:collection_weapon, weapon: ssr_weapon) }
    let!(:sr_collection) { create(:collection_weapon, weapon: sr_weapon) }
    let!(:transcended) { create(:collection_weapon, :transcended) }
    let!(:with_awakening) { create(:collection_weapon, :with_awakening) }
    let!(:with_keys) { create(:collection_weapon, :with_keys) }

    describe '.by_element' do
      it 'returns weapons of specified element' do
        expect(CollectionWeapon.by_element(0)).to include(fire_collection)
        expect(CollectionWeapon.by_element(0)).not_to include(water_collection)
      end
    end

    describe '.by_rarity' do
      it 'returns weapons of specified rarity' do
        expect(CollectionWeapon.by_rarity(4)).to include(ssr_collection)
        expect(CollectionWeapon.by_rarity(4)).not_to include(sr_collection)
      end
    end

    describe '.transcended' do
      it 'returns only transcended weapons' do
        expect(CollectionWeapon.transcended).to include(transcended)
        expect(CollectionWeapon.transcended).not_to include(fire_collection)
      end
    end

    describe '.with_awakening' do
      it 'returns only weapons with awakening' do
        expect(CollectionWeapon.with_awakening).to include(with_awakening)
        expect(CollectionWeapon.with_awakening).not_to include(fire_collection)
      end
    end

    describe '.with_keys' do
      it 'returns only weapons with keys' do
        expect(CollectionWeapon.with_keys).to include(with_keys)
        expect(CollectionWeapon.with_keys).not_to include(fire_collection)
      end
    end
  end

  describe 'factory traits' do
    describe ':maxed trait' do
      it 'creates a fully upgraded weapon' do
        maxed = create(:collection_weapon, :maxed)

        aggregate_failures do
          expect(maxed.uncap_level).to eq(5)
          expect(maxed.transcendence_step).to eq(10)
          expect(maxed.awakening).to be_present
          expect(maxed.awakening_level).to eq(10)
          expect(maxed.weapon_key1).to be_present
          expect(maxed.weapon_key2).to be_present
          expect(maxed.weapon_key3).to be_present
        end
      end
    end

    describe ':with_ax trait' do
      it 'creates a weapon with AX skills' do
        ax_weapon = create(:collection_weapon, :with_ax)

        aggregate_failures do
          expect(ax_weapon.ax_modifier1).to be_a(WeaponStatModifier)
          expect(ax_weapon.ax_modifier1.slug).to eq('ax_atk')
          expect(ax_weapon.ax_strength1).to eq(3.5)
          expect(ax_weapon.ax_modifier2).to be_a(WeaponStatModifier)
          expect(ax_weapon.ax_modifier2.slug).to eq('ax_hp')
          expect(ax_weapon.ax_strength2).to eq(10.0)
        end
      end
    end

    describe ':with_four_keys trait' do
      it 'creates a weapon with all four keys' do
        four_key_weapon = create(:collection_weapon, :with_four_keys)

        aggregate_failures do
          expect(four_key_weapon.weapon_key1).to be_present
          expect(four_key_weapon.weapon_key2).to be_present
          expect(four_key_weapon.weapon_key3).to be_present
          expect(four_key_weapon.weapon_key4).to be_present
        end
      end
    end
  end
end