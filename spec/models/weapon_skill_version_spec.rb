# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkillVersion, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:weapon_skill) }
    it { is_expected.to belong_to(:skill) }
  end

  describe 'enums' do
    it 'defines skill_series enum' do
      expect(described_class.skill_series).to eq(
        'normal' => 'normal', 'omega' => 'omega', 'ex' => 'ex', 'odious' => 'odious'
      )
    end

    it 'defines skill_size enum' do
      expect(described_class.skill_sizes).to eq(
        'small' => 'small', 'medium' => 'medium', 'big' => 'big', 'big_ii' => 'big_ii',
        'massive' => 'massive', 'unworldly' => 'unworldly', 'ancestral' => 'ancestral'
      )
    end
  end

  describe 'validations' do
    subject { build(:weapon_skill_version) }

    it { is_expected.to validate_presence_of(:ordinal) }
    it { is_expected.to validate_numericality_of(:ordinal).only_integer.is_greater_than_or_equal_to(0) }

    context 'skill_modifier inclusion' do
      it 'allows nil' do
        expect(build(:weapon_skill_version, skill_modifier: nil)).to be_valid
      end

      it 'allows a valid modifier' do
        expect(build(:weapon_skill_version, skill_modifier: 'Might')).to be_valid
      end

      it 'rejects an invalid modifier' do
        v = build(:weapon_skill_version, skill_modifier: 'NotARealModifier')
        expect(v).not_to be_valid
        expect(v.errors[:skill_modifier]).to include('is not included in the list')
      end
    end
  end

  describe 'name/description delegation' do
    it 'reads name and description from the canonical Skill (no local copies)' do
      skill = create(:skill, skill_type: :weapon, name_en: 'Optimus Exalto Aquae', description_en: '30% boost')
      version = create(:weapon_skill_version, skill: skill)
      expect(version.name_en).to eq('Optimus Exalto Aquae')
      expect(version.description_en).to eq('30% boost')
      expect(described_class.column_names).not_to include('name_en', 'description_en')
    end
  end

  describe '#weapon_skill_data' do
    it 'looks up scaling by modifier/series/size' do
      version = build(:weapon_skill_version, skill_modifier: 'Might', skill_series: :normal, skill_size: :big)
      expect(WeaponSkillDatum).to receive(:for_skill).with(modifier: 'Might', series: 'normal', size: 'big')
      version.weapon_skill_data
    end
  end

  describe 'VALID_MODIFIERS' do
    it 'equals WeaponSkillParser::KNOWN_MODIFIERS' do
      expect(described_class::VALID_MODIFIERS).to eq(Granblue::Parsers::WeaponSkillParser::KNOWN_MODIFIERS)
    end
  end
end
