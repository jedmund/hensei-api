# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Skill, type: :model do
  describe 'enums' do
    it 'defines skill_type enum' do
      expect(described_class.skill_types).to eq(
        'character' => 0,
        'charge_attack' => 1,
        'summon' => 2,
        'weapon' => 3
      )
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
    end
  end
end
