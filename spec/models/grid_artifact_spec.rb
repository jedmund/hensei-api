# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridArtifact, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:grid_character) }
    it { is_expected.to belong_to(:artifact) }
    it { is_expected.to belong_to(:collection_artifact).optional }
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

  describe 'Collection Sync' do
    before do
      ArtifactSkill.find_or_create_by!(skill_group: :group_i, modifier: 1) do |s|
        s.name_en = 'ATK'
        s.name_jp = '攻撃力'
        s.base_values = [1320, 1440, 1560, 1680, 1800]
        s.growth = 300.0
        s.polarity = :positive
      end
      ArtifactSkill.find_or_create_by!(skill_group: :group_i, modifier: 2) do |s|
        s.name_en = 'HP'
        s.name_jp = 'HP'
        s.base_values = [660, 720, 780, 840, 900]
        s.growth = 150.0
        s.polarity = :positive
      end
      ArtifactSkill.find_or_create_by!(skill_group: :group_ii, modifier: 1) do |s|
        s.name_en = 'C.A. DMG'
        s.name_jp = '奥義ダメ'
        s.base_values = [13.2, 14.4, 15.6, 16.8, 18.0]
        s.growth = 3.0
        s.polarity = :positive
      end
      ArtifactSkill.find_or_create_by!(skill_group: :group_iii, modifier: 1) do |s|
        s.name_en = 'Chain Burst DMG'
        s.name_jp = 'チェインダメ'
        s.base_values = [6, 7, 8, 9, 10]
        s.growth = 2.5
        s.polarity = :positive
      end
      ArtifactSkill.clear_cache!
    end

    let(:user) { create(:user) }
    let(:grid_character) { create(:grid_character) }
    let(:artifact) { create(:artifact) }
    let(:collection_artifact) do
      create(:collection_artifact,
             user: user,
             artifact: artifact,
             element: :light,
             level: 4,
             skill1: { 'modifier' => 1, 'quality' => 3, 'level' => 2 },
             skill2: { 'modifier' => 2, 'quality' => 3, 'level' => 2 },
             skill3: { 'modifier' => 1, 'quality' => 3, 'level' => 2 },
             skill4: { 'modifier' => 1, 'quality' => 3, 'level' => 1 },
             reroll_slot: 3)
    end

    describe '#sync_from_collection!' do
      context 'when collection_artifact is linked' do
        let(:linked_grid_artifact) do
          create(:grid_artifact,
                 grid_character: grid_character,
                 artifact: artifact,
                 collection_artifact: collection_artifact,
                 element: :light,
                 level: 2,
                 skill1: {}, skill2: {}, skill3: {}, skill4: {})
        end

        it 'copies customizations from collection' do
          expect(linked_grid_artifact.sync_from_collection!).to be true
          linked_grid_artifact.reload

          expect(linked_grid_artifact.element).to eq('light')
          expect(linked_grid_artifact.level).to eq(4)
          expect(linked_grid_artifact.skill1).to eq({ 'modifier' => 1, 'quality' => 3, 'level' => 2 })
          expect(linked_grid_artifact.reroll_slot).to eq(3)
        end
      end

      context 'when no collection_artifact is linked' do
        let(:unlinked_grid_artifact) do
          create(:grid_artifact,
                 grid_character: grid_character,
                 artifact: artifact,
                 element: :light,
                 level: 2,
                 skill1: {}, skill2: {}, skill3: {}, skill4: {})
        end

        it 'returns false' do
          expect(unlinked_grid_artifact.sync_from_collection!).to be false
        end
      end
    end

    describe '#out_of_sync?' do
      context 'when collection_artifact is linked' do
        let(:linked_grid_artifact) do
          create(:grid_artifact,
                 grid_character: grid_character,
                 artifact: artifact,
                 collection_artifact: collection_artifact,
                 element: :light,
                 level: 2,
                 skill1: {}, skill2: {}, skill3: {}, skill4: {})
        end

        it 'returns true when values differ' do
          expect(linked_grid_artifact.out_of_sync?).to be true
        end

        it 'returns false after sync' do
          linked_grid_artifact.sync_from_collection!
          expect(linked_grid_artifact.out_of_sync?).to be false
        end
      end

      context 'when no collection_artifact is linked' do
        let(:unlinked_grid_artifact) do
          create(:grid_artifact,
                 grid_character: grid_character,
                 artifact: artifact,
                 element: :light,
                 level: 2,
                 skill1: {}, skill2: {}, skill3: {}, skill4: {})
        end

        it 'returns false' do
          expect(unlinked_grid_artifact.out_of_sync?).to be false
        end
      end
    end
  end
end
