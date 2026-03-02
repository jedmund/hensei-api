# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkill, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:skill) }
  end

  describe 'enums' do
    it 'defines skill_series enum' do
      expect(described_class.skill_series).to eq(
        'normal' => 'normal',
        'omega' => 'omega',
        'ex' => 'ex',
        'odious' => 'odious'
      )
    end

    it 'defines skill_size enum' do
      expect(described_class.skill_sizes).to eq(
        'small' => 'small',
        'medium' => 'medium',
        'big' => 'big',
        'big_ii' => 'big_ii',
        'massive' => 'massive',
        'unworldly' => 'unworldly',
        'ancestral' => 'ancestral'
      )
    end
  end

  describe 'validations' do
    let(:weapon) { create(:weapon) }
    let(:skill) { create(:skill) }
    subject { build(:weapon_skill, weapon: weapon, skill: skill, position: 0) }

    it { is_expected.to validate_presence_of(:weapon_granblue_id) }
    it { is_expected.to validate_presence_of(:skill_id) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:uncap_level) }
    it { is_expected.to validate_numericality_of(:uncap_level).only_integer.is_greater_than_or_equal_to(0) }

    context 'position uniqueness' do
      it 'validates uniqueness scoped to weapon and uncap_level' do
        create(:weapon_skill, weapon: weapon, skill: skill, position: 0, uncap_level: 0)
        duplicate = build(:weapon_skill, weapon: weapon, skill: create(:skill), position: 0, uncap_level: 0)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to include('has already been taken')
      end

      it 'allows same position on same weapon with different uncap_level' do
        create(:weapon_skill, weapon: weapon, skill: skill, position: 0, uncap_level: 0)
        upgrade = build(:weapon_skill, weapon: weapon, skill: create(:skill), position: 0, uncap_level: 4)
        expect(upgrade).to be_valid
      end

      it 'allows same position on different weapons' do
        other_weapon = create(:weapon)
        create(:weapon_skill, weapon: weapon, skill: skill, position: 0, uncap_level: 0)
        other = build(:weapon_skill, weapon: other_weapon, skill: create(:skill), position: 0, uncap_level: 0)
        expect(other).to be_valid
      end
    end

    context 'skill_modifier inclusion' do
      it 'allows nil skill_modifier' do
        ws = build(:weapon_skill, weapon: weapon, skill: skill, position: 0, skill_modifier: nil)
        expect(ws).to be_valid
      end

      it 'allows a valid modifier' do
        ws = build(:weapon_skill, weapon: weapon, skill: skill, position: 0, skill_modifier: 'Might')
        expect(ws).to be_valid
      end

      it 'rejects an invalid modifier' do
        ws = build(:weapon_skill, weapon: weapon, skill: skill, position: 0, skill_modifier: 'InvalidModName')
        expect(ws).not_to be_valid
        expect(ws.errors[:skill_modifier]).to include('is not included in the list')
      end
    end
  end

  describe 'VALID_MODIFIERS' do
    it 'equals WeaponSkillParser::KNOWN_MODIFIERS' do
      expect(described_class::VALID_MODIFIERS).to eq(Granblue::Parsers::WeaponSkillParser::KNOWN_MODIFIERS)
    end

    it 'includes boostable modifiers' do
      %w[Might Enmity Stamina Trium Majesty].each do |mod|
        expect(described_class::VALID_MODIFIERS).to include(mod)
      end
    end

    it 'includes flat modifiers' do
      %w[Godblade Excelsior Supremacy].each do |mod|
        expect(described_class::VALID_MODIFIERS).to include(mod)
      end
    end

    it 'includes multi-word modifiers' do
      expect(described_class::VALID_MODIFIERS).to include('Omega Exalto')
      expect(described_class::VALID_MODIFIERS).to include('Sephira Tek')
    end
  end
end
