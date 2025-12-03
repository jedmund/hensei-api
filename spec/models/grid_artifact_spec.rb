# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridArtifact, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:grid_character) }
    it { is_expected.to belong_to(:artifact) }
  end

  describe 'validations' do
    subject { build(:grid_artifact, skill1: {}, skill2: {}, skill3: {}, skill4: {}) }

    it { is_expected.to validate_presence_of(:element) }

    it 'validates presence of level' do
      subject.level = nil
      expect(subject).not_to be_valid
    end

    it 'validates level is between 1 and 5' do
      artifact = build(:grid_artifact, skill1: {}, skill2: {}, skill3: {}, skill4: {})
      artifact.level = 0
      expect(artifact).not_to be_valid

      artifact.level = 6
      expect(artifact).not_to be_valid

      artifact.level = 3
      expect(artifact).to be_valid
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

  describe 'relationship with grid_character' do
    it 'belongs to a grid_character' do
      grid_character = create(:grid_character)
      grid_artifact = create(:grid_artifact,
        grid_character: grid_character,
        skill1: {}, skill2: {}, skill3: {}, skill4: {}
      )
      expect(grid_artifact.grid_character).to eq(grid_character)
    end

    # Note: The controller handles uniqueness by destroying existing artifact before creating new one
    # See GridArtifactsController#create lines 15-17
  end

  describe 'amoeba duplication' do
    let(:grid_character) { create(:grid_character) }
    let(:grid_artifact) { create(:grid_artifact, grid_character: grid_character) }

    it 'can be duplicated via amoeba' do
      expect(GridArtifact).to respond_to(:amoeba_block)
    end
  end
end
