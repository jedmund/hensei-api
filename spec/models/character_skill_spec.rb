# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkill, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:character).inverse_of(:character_skills) }

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

  describe 'character_granblue_id' do
    it "is set from the owning character's granblue_id" do
      character = create(:character, granblue_id: '3990000001')
      skill = described_class.new(character: character, kind: :ability, position: 1)

      skill.valid?

      expect(skill.character_granblue_id).to eq('3990000001')
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

      it "allows the same position on a style row that shares the base's granblue_id" do
        create(:character_skill, character: character, kind: :ability, position: 1)
        style = create(:character, granblue_id: character.granblue_id, style_swap: true)
        styled = build(:character_skill, character: style, kind: :ability, position: 1)

        expect(styled).to be_valid
      end
    end
  end
end
