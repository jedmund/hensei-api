# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkill, type: :model do
  describe 'associations' do
    it 'belongs to character by granblue_id' do
      reflection = described_class.reflect_on_association(:character)

      aggregate_failures do
        expect(reflection.macro).to eq(:belongs_to)
        expect(reflection.options[:primary_key]).to eq(:granblue_id)
        expect(reflection.options[:foreign_key]).to eq(:character_granblue_id)
        expect(reflection.options[:inverse_of]).to eq(:character_skills)
      end
    end

    it { is_expected.to have_many(:character_skill_versions).dependent(:destroy).inverse_of(:character_skill) }
  end

  describe 'enums' do
    it 'defines kind enum' do
      expect(described_class.kinds).to eq(
        'ability' => 'ability',
        'ougi' => 'ougi',
        'support' => 'support'
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:character_granblue_id) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    context 'position uniqueness' do
      let(:character) { create(:character) }

      it 'validates uniqueness scoped to character and kind' do
        create(:character_skill, character: character, kind: :ability, position: 1)
        duplicate = build(:character_skill, character: character, kind: :ability, position: 1)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:position]).to include('has already been taken')
      end

      it 'allows the same position for another kind' do
        create(:character_skill, character: character, kind: :ability, position: 1)
        support = build(:character_skill, character: character, kind: :support, position: 1)

        expect(support).to be_valid
      end

      it 'allows the same position for another character' do
        create(:character_skill, character: character, kind: :ability, position: 1)
        other = build(:character_skill, character: create(:character), kind: :ability, position: 1)

        expect(other).to be_valid
      end
    end
  end
end
