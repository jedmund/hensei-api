require 'rails_helper'

RSpec.describe CollectionSummon, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:summon) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:summon) { create(:summon) }

    subject { build(:collection_summon, user: user, summon: summon) }

    describe 'basic validations' do
      it { should validate_inclusion_of(:uncap_level).in_range(0..5) }
      it { should validate_inclusion_of(:transcendence_step).in_range(0..10) }
    end

    describe 'transcendence validations' do
      context 'when transcendence_step > 0 with uncap_level < 5' do
        it 'is invalid' do
          collection_summon = build(:collection_summon, uncap_level: 4, transcendence_step: 1)
          expect(collection_summon).not_to be_valid
          expect(collection_summon.errors[:transcendence_step]).to include('requires uncap level 5 (current: 4)')
        end
      end

      context 'when transcendence_step > 0 with uncap_level = 5' do
        it 'is valid for transcendable summon' do
          transcendable_summon = create(:summon, :transcendable)
          collection_summon = build(:collection_summon, summon: transcendable_summon, uncap_level: 5, transcendence_step: 5)
          expect(collection_summon).to be_valid
        end
      end

      context 'when transcendence_step = 0 with any uncap_level' do
        it 'is valid' do
          collection_summon = build(:collection_summon, uncap_level: 3, transcendence_step: 0)
          expect(collection_summon).to be_valid
        end
      end

      context 'when transcendence_step > 0 for non-transcendable summon' do
        it 'is invalid' do
          non_trans_summon = create(:summon, transcendence: false)
          collection_summon = build(:collection_summon, summon: non_trans_summon, uncap_level: 5, transcendence_step: 1)
          expect(collection_summon).not_to be_valid
          expect(collection_summon.errors[:transcendence_step]).to include('not available for this summon')
        end
      end
    end
  end

  describe 'scopes' do
    let!(:fire_summon) { create(:summon, element: 0) }
    let!(:water_summon) { create(:summon, element: 1) }
    let!(:ssr_summon) { create(:summon, rarity: 4) }
    let!(:sr_summon) { create(:summon, rarity: 3) }

    let!(:fire_collection) { create(:collection_summon, summon: fire_summon) }
    let!(:water_collection) { create(:collection_summon, summon: water_summon) }
    let!(:ssr_collection) { create(:collection_summon, summon: ssr_summon) }
    let!(:sr_collection) { create(:collection_summon, summon: sr_summon) }
    let!(:transcended) { create(:collection_summon, :transcended) }

    describe '.by_element' do
      it 'returns summons of specified element' do
        expect(CollectionSummon.by_element(0)).to include(fire_collection)
        expect(CollectionSummon.by_element(0)).not_to include(water_collection)
      end
    end

    describe '.by_rarity' do
      it 'returns summons of specified rarity' do
        expect(CollectionSummon.by_rarity(4)).to include(ssr_collection)
        expect(CollectionSummon.by_rarity(4)).not_to include(sr_collection)
      end
    end

    describe '.transcended' do
      it 'returns only transcended summons' do
        expect(CollectionSummon.transcended).to include(transcended)
        expect(CollectionSummon.transcended).not_to include(fire_collection)
      end
    end

    describe '.max_uncapped' do
      let!(:max_uncapped) { create(:collection_summon, uncap_level: 5) }
      let!(:partial_uncapped) { create(:collection_summon, uncap_level: 3) }

      it 'returns only max uncapped summons' do
        expect(CollectionSummon.max_uncapped).to include(max_uncapped)
        expect(CollectionSummon.max_uncapped).not_to include(partial_uncapped)
      end
    end
  end

  describe 'factory traits' do
    describe ':max_uncap trait' do
      it 'creates a max uncapped summon' do
        max_uncap = create(:collection_summon, :max_uncap)
        expect(max_uncap.uncap_level).to eq(5)
      end
    end

    describe ':transcended trait' do
      it 'creates a transcended summon' do
        transcended = create(:collection_summon, :transcended)

        aggregate_failures do
          expect(transcended.uncap_level).to eq(5)
          expect(transcended.transcendence_step).to eq(5)
          expect(transcended).to be_valid
        end
      end
    end

    describe ':max_transcended trait' do
      it 'creates a fully transcended summon' do
        max_transcended = create(:collection_summon, :max_transcended)

        aggregate_failures do
          expect(max_transcended.uncap_level).to eq(5)
          expect(max_transcended.transcendence_step).to eq(10)
          expect(max_transcended).to be_valid
        end
      end
    end
  end
end