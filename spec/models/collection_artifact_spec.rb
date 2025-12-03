# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionArtifact, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:artifact) }
  end

  describe 'validations' do
    subject { build(:collection_artifact, skill1: {}, skill2: {}, skill3: {}, skill4: {}) }

    it { is_expected.to validate_presence_of(:element) }

    it 'validates presence of level' do
      subject.level = nil
      expect(subject).not_to be_valid
    end

    it 'validates level is between 1 and 5' do
      artifact = build(:collection_artifact, skill1: {}, skill2: {}, skill3: {}, skill4: {})
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
      expect(CollectionArtifact.elements).to include(
        'wind' => 1,
        'fire' => 2,
        'water' => 3,
        'earth' => 4,
        'dark' => 5,
        'light' => 6
      )
    end

    it 'defines proficiency enum' do
      expect(CollectionArtifact.proficiencies).to include(
        'sabre' => 1,
        'dagger' => 2
      )
    end
  end

  describe '#effective_proficiency' do
    context 'for standard artifact' do
      let(:artifact) { create(:artifact, proficiency: :dagger) }

      it 'returns proficiency from base artifact' do
        collection_artifact = build(:collection_artifact,
          artifact: artifact,
          proficiency: nil,
          skill1: {}, skill2: {}, skill3: {}, skill4: {}
        )
        expect(collection_artifact.effective_proficiency).to eq('dagger')
      end
    end

    context 'for quirk artifact' do
      let(:artifact) { create(:artifact, :quirk) }

      it 'returns proficiency from instance' do
        collection_artifact = build(:collection_artifact,
          artifact: artifact,
          proficiency: :staff,
          level: 1,
          skill1: {}, skill2: {}, skill3: {}, skill4: {}
        )
        expect(collection_artifact.effective_proficiency).to eq('staff')
      end
    end
  end

  describe 'skill validations' do
    before do
      # Seed the required artifact skills for validation
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

    it 'is valid with correct skills' do
      artifact = create(:artifact)
      collection_artifact = build(:collection_artifact,
        artifact: artifact,
        level: 1,
        skill1: { 'modifier' => 1, 'strength' => 1800, 'level' => 1 },
        skill2: { 'modifier' => 2, 'strength' => 900, 'level' => 1 },
        skill3: { 'modifier' => 1, 'strength' => 18.0, 'level' => 1 },
        skill4: { 'modifier' => 1, 'strength' => 10, 'level' => 1 }
      )
      expect(collection_artifact).to be_valid
    end

    it 'is invalid when skill1 and skill2 have the same modifier' do
      artifact = create(:artifact)
      collection_artifact = build(:collection_artifact,
        artifact: artifact,
        level: 1,
        skill1: { 'modifier' => 1, 'strength' => 1800, 'level' => 1 },
        skill2: { 'modifier' => 1, 'strength' => 1800, 'level' => 1 }, # Same modifier
        skill3: { 'modifier' => 1, 'strength' => 18.0, 'level' => 1 },
        skill4: { 'modifier' => 1, 'strength' => 10, 'level' => 1 }
      )
      expect(collection_artifact).not_to be_valid
      expect(collection_artifact.errors[:base]).to include('Skill 1 and Skill 2 cannot have the same modifier')
    end

    it 'validates skill levels sum correctly' do
      artifact = create(:artifact)
      # At level 1, skill levels must sum to 4 (1 + 3)
      collection_artifact = build(:collection_artifact,
        artifact: artifact,
        level: 1,
        skill1: { 'modifier' => 1, 'strength' => 1800, 'level' => 2 },
        skill2: { 'modifier' => 2, 'strength' => 900, 'level' => 2 },
        skill3: { 'modifier' => 1, 'strength' => 18.0, 'level' => 2 },
        skill4: { 'modifier' => 1, 'strength' => 10, 'level' => 2 }
      )
      expect(collection_artifact).not_to be_valid
      expect(collection_artifact.errors[:base].first).to include('Skill levels must sum to')
    end
  end

  describe 'quirk artifact constraints' do
    let(:quirk_artifact) { create(:artifact, :quirk) }

    it 'requires level 1 for quirk artifacts' do
      collection_artifact = build(:collection_artifact,
        artifact: quirk_artifact,
        proficiency: :sabre,
        level: 3,
        skill1: {},
        skill2: {},
        skill3: {},
        skill4: {}
      )
      expect(collection_artifact).not_to be_valid
      expect(collection_artifact.errors[:level]).to include('must be 1 for quirk artifacts')
    end

    it 'requires empty skills for quirk artifacts' do
      collection_artifact = build(:collection_artifact,
        artifact: quirk_artifact,
        proficiency: :sabre,
        level: 1,
        skill1: { 'modifier' => 1, 'strength' => 1800, 'level' => 1 },
        skill2: {},
        skill3: {},
        skill4: {}
      )
      expect(collection_artifact).not_to be_valid
      expect(collection_artifact.errors[:skill1]).to include('must be empty for quirk artifacts')
    end

    it 'is valid with empty skills and level 1' do
      collection_artifact = build(:collection_artifact,
        artifact: quirk_artifact,
        proficiency: :sabre,
        level: 1,
        skill1: {},
        skill2: {},
        skill3: {},
        skill4: {}
      )
      expect(collection_artifact).to be_valid
    end
  end
end
