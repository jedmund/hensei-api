require 'rails_helper'

RSpec.describe CollectionCharacter, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:character) }
    it { should belong_to(:awakening).optional }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:character) { create(:character) }

    subject { build(:collection_character, user: user, character: character) }

    describe 'basic validations' do
      it { should validate_inclusion_of(:uncap_level).in_range(0..5) }
      it { should validate_inclusion_of(:transcendence_step).in_range(0..10) }
      it { should validate_inclusion_of(:awakening_level).in_range(1..10) }
    end

    describe 'uniqueness validation' do
      it { should validate_uniqueness_of(:character_id).scoped_to(:user_id).ignoring_case_sensitivity.with_message('already exists in your collection') }
    end

    describe 'ring validations' do
      context 'when ring has only modifier' do
        it 'is invalid' do
          collection_char = build(:collection_character, ring1: { modifier: 1, strength: nil })
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:base]).to include('Ring 1 must have both modifier and strength')
        end
      end

      context 'when ring has only strength' do
        it 'is invalid' do
          collection_char = build(:collection_character, ring2: { modifier: nil, strength: 10.5 })
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:base]).to include('Ring 2 must have both modifier and strength')
        end
      end

      context 'when ring has both modifier and strength' do
        it 'is valid' do
          collection_char = build(:collection_character, ring1: { modifier: 1, strength: 10.5 })
          expect(collection_char).to be_valid
        end
      end

      context 'when ring has neither modifier nor strength' do
        it 'is valid' do
          collection_char = build(:collection_character, ring1: { modifier: nil, strength: nil })
          expect(collection_char).to be_valid
        end
      end

      context 'when earring has invalid data' do
        it 'validates earring like rings' do
          collection_char = build(:collection_character, earring: { modifier: 5, strength: nil })
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:base]).to include('Ring 5 must have both modifier and strength')
        end
      end
    end

    describe 'awakening validations' do
      context 'when awakening is for wrong object type' do
        it 'is invalid' do
          weapon_awakening = create(:awakening, object_type: 'Weapon')
          collection_char = build(:collection_character, awakening: weapon_awakening)
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:awakening]).to include('must be a character awakening')
        end
      end

      context 'when awakening is for correct object type' do
        it 'is valid' do
          char_awakening = create(:awakening, object_type: 'Character')
          collection_char = build(:collection_character, awakening: char_awakening)
          expect(collection_char).to be_valid
        end
      end

      context 'when awakening_level > 1 without awakening' do
        it 'is invalid' do
          collection_char = build(:collection_character, awakening: nil, awakening_level: 5)
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:awakening_level]).to include('cannot be set without an awakening')
        end
      end

      context 'when awakening_level is 1 without awakening' do
        it 'is valid' do
          collection_char = build(:collection_character, awakening: nil, awakening_level: 1)
          expect(collection_char).to be_valid
        end
      end
    end

    describe 'transcendence validations' do
      context 'when transcendence_step > 0 with uncap_level < 5' do
        it 'is invalid' do
          collection_char = build(:collection_character, uncap_level: 4, transcendence_step: 1)
          expect(collection_char).not_to be_valid
          expect(collection_char.errors[:transcendence_step]).to include('requires uncap level 5 (current: 4)')
        end
      end

      context 'when transcendence_step > 0 with uncap_level = 5' do
        it 'is valid' do
          collection_char = build(:collection_character, uncap_level: 5, transcendence_step: 5)
          expect(collection_char).to be_valid
        end
      end

      context 'when transcendence_step = 0 with any uncap_level' do
        it 'is valid' do
          collection_char = build(:collection_character, uncap_level: 3, transcendence_step: 0)
          expect(collection_char).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let!(:fire_char) { create(:character, element: 0) }
    let!(:water_char) { create(:character, element: 1) }
    let!(:ssr_char) { create(:character, rarity: 4) }
    let!(:sr_char) { create(:character, rarity: 3) }

    let!(:fire_collection) { create(:collection_character, character: fire_char) }
    let!(:water_collection) { create(:collection_character, character: water_char) }
    let!(:ssr_collection) { create(:collection_character, character: ssr_char) }
    let!(:sr_collection) { create(:collection_character, character: sr_char) }
    let!(:transcended) { create(:collection_character, :transcended) }
    let!(:awakened) { create(:collection_character, :with_awakening) }

    describe '.by_element' do
      it 'returns characters of specified element' do
        expect(CollectionCharacter.by_element(0)).to include(fire_collection)
        expect(CollectionCharacter.by_element(0)).not_to include(water_collection)
      end
    end

    describe '.by_rarity' do
      it 'returns characters of specified rarity' do
        expect(CollectionCharacter.by_rarity(4)).to include(ssr_collection)
        expect(CollectionCharacter.by_rarity(4)).not_to include(sr_collection)
      end
    end

    describe '.transcended' do
      it 'returns only transcended characters' do
        expect(CollectionCharacter.transcended).to include(transcended)
        expect(CollectionCharacter.transcended).not_to include(fire_collection)
      end
    end

    describe '.with_awakening' do
      it 'returns only characters with awakening' do
        expect(CollectionCharacter.with_awakening).to include(awakened)
        expect(CollectionCharacter.with_awakening).not_to include(fire_collection)
      end
    end
  end

  describe 'factory traits' do
    describe ':maxed trait' do
      it 'creates a fully upgraded character' do
        maxed = create(:collection_character, :maxed)

        aggregate_failures do
          expect(maxed.uncap_level).to eq(5)
          expect(maxed.transcendence_step).to eq(10)
          expect(maxed.perpetuity).to be true
          expect(maxed.awakening).to be_present
          expect(maxed.awakening_level).to eq(10)
          expect(maxed.ring1['modifier']).to be_present
          expect(maxed.earring['modifier']).to be_present
        end
      end
    end

    describe ':transcended trait' do
      it 'creates a transcended character with proper uncap' do
        transcended = create(:collection_character, :transcended)

        expect(transcended.uncap_level).to eq(5)
        expect(transcended.transcendence_step).to eq(5)
        expect(transcended).to be_valid
      end
    end
  end
end