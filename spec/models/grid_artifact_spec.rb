# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridArtifact, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:grid_character) }
    it { is_expected.to belong_to(:artifact) }
  end

  describe 'validations' do
    subject { build(:grid_artifact) }

    it { is_expected.to validate_presence_of(:element) }

    it 'validates presence of level' do
      subject.level = nil
      expect(subject).not_to be_valid
    end

    it 'validates level is between 1 and 5' do
      subject.level = 0
      expect(subject).not_to be_valid

      subject.level = 6
      expect(subject).not_to be_valid

      subject.level = 3
      expect(subject).to be_valid
    end
  end

  describe 'enums' do
    it 'defines element enum' do
      expect(GridArtifact.elements).to include(
        'wind' => 1,
        'fire' => 2,
        'water' => 3,
        'earth' => 4
      )
    end
  end

  describe '#effective_proficiency' do
    context 'for standard artifact' do
      let(:artifact) { create(:artifact, proficiency: :spear) }

      it 'returns proficiency from base artifact' do
        grid_artifact = build(:grid_artifact,
          artifact: artifact,
          proficiency: nil,
          skill1: {}, skill2: {}, skill3: {}, skill4: {}
        )
        expect(grid_artifact.effective_proficiency).to eq('spear')
      end
    end

    context 'for quirk artifact' do
      let(:artifact) { create(:artifact, :quirk) }

      it 'returns proficiency from instance' do
        grid_artifact = build(:grid_artifact,
          artifact: artifact,
          proficiency: :melee,
          level: 1,
          skill1: {}, skill2: {}, skill3: {}, skill4: {}
        )
        expect(grid_artifact.effective_proficiency).to eq('melee')
      end
    end
  end

  describe 'unique constraint on grid_character' do
    it 'does not allow duplicate grid_artifacts for same grid_character' do
      grid_character = create(:grid_character)
      create(:grid_artifact,
        grid_character: grid_character,
        skill1: {}, skill2: {}, skill3: {}, skill4: {}
      )
      duplicate = build(:grid_artifact,
        grid_character: grid_character,
        skill1: {}, skill2: {}, skill3: {}, skill4: {}
      )
      expect(duplicate).not_to be_valid
    end
  end

  describe 'amoeba duplication' do
    let(:grid_character) { create(:grid_character) }
    let(:grid_artifact) { create(:grid_artifact, grid_character: grid_character) }

    it 'can be duplicated via amoeba' do
      expect(GridArtifact).to respond_to(:amoeba_block)
    end
  end
end
