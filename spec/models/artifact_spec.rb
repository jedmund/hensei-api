# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Artifact, type: :model do
  describe 'validations' do
    subject { build(:artifact) }

    it { is_expected.to validate_presence_of(:granblue_id) }
    it 'validates uniqueness of granblue_id' do
      create(:artifact)
      duplicate = build(:artifact, granblue_id: Artifact.first.granblue_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:granblue_id]).to include('has already been taken')
    end
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:rarity) }

    context 'when standard artifact' do
      subject { build(:artifact, rarity: :standard) }

      it { is_expected.to validate_presence_of(:proficiency) }
    end

    context 'when quirk artifact' do
      subject { build(:artifact, :quirk) }

      it 'requires proficiency to be nil' do
        subject.proficiency = :sabre
        expect(subject).not_to be_valid
        expect(subject.errors[:proficiency]).to include('must be blank')
      end

      it 'is valid without proficiency' do
        expect(subject).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:collection_artifacts).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:grid_artifacts).dependent(:restrict_with_error) }
  end

  describe 'enums' do
    it 'defines proficiency enum' do
      expect(Artifact.proficiencies).to include(
        'sabre' => 1,
        'dagger' => 2,
        'spear' => 4
      )
    end

    it 'defines rarity enum' do
      expect(Artifact.rarities).to eq('standard' => 0, 'quirk' => 1)
    end
  end

  describe 'scopes' do
    let!(:standard_artifact) { create(:artifact, rarity: :standard) }
    let!(:quirk_artifact) { create(:artifact, :quirk) }

    it 'filters by rarity' do
      expect(Artifact.standard).to include(standard_artifact)
      expect(Artifact.standard).not_to include(quirk_artifact)
      expect(Artifact.quirk).to include(quirk_artifact)
      expect(Artifact.quirk).not_to include(standard_artifact)
    end
  end

  describe '#quirk?' do
    it 'returns true for quirk artifacts' do
      artifact = build(:artifact, :quirk)
      expect(artifact.quirk?).to be true
    end

    it 'returns false for standard artifacts' do
      artifact = build(:artifact, rarity: :standard)
      expect(artifact.quirk?).to be false
    end
  end
end
