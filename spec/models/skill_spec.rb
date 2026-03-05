# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Skill, type: :model do
  describe 'enums' do
    it 'defines skill_type enum with correct values' do
      expect(described_class.skill_types).to eq(
        'character' => 0,
        'charge_attack' => 1,
        'summon' => 2,
        'weapon' => 3
      )
    end

    it 'supports querying by skill_type' do
      weapon_skill = create(:skill, :weapon, name_en: 'Weapon Skill')
      character_skill = create(:skill, :character, name_en: 'Character Skill')

      expect(Skill.weapon).to include(weapon_skill)
      expect(Skill.weapon).not_to include(character_skill)
      expect(Skill.character).to include(character_skill)
      expect(Skill.character).not_to include(weapon_skill)
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:weapon_skills).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:skill) }

    it { is_expected.to validate_presence_of(:name_en) }

    it 'is valid with just name_en and skill_type' do
      skill = build(:skill, name_en: 'Test', skill_type: :weapon)
      expect(skill).to be_valid
    end

    it 'is invalid without name_en' do
      skill = build(:skill, name_en: nil)
      expect(skill).not_to be_valid
      expect(skill.errors[:name_en]).to include("can't be blank")
    end
  end
end
