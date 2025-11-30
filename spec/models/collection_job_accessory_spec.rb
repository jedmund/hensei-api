require 'rails_helper'

RSpec.describe CollectionJobAccessory, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:job_accessory) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:job) { create(:job) }
    let(:job_accessory) { create(:job_accessory, job: job) }

    subject { build(:collection_job_accessory, user: user, job_accessory: job_accessory) }

    describe 'uniqueness validation' do
      it { should validate_uniqueness_of(:job_accessory_id).scoped_to(:user_id).ignoring_case_sensitivity.with_message('already exists in your collection') }
    end
  end

  describe 'scopes' do
    let!(:warrior_job) { create(:job, name_en: 'Warrior') }
    let!(:sage_job) { create(:job, name_en: 'Sage') }

    let!(:warrior_accessory) { create(:job_accessory, job: warrior_job) }
    let!(:sage_accessory) { create(:job_accessory, job: sage_job) }

    let!(:warrior_collection) { create(:collection_job_accessory, job_accessory: warrior_accessory) }
    let!(:sage_collection) { create(:collection_job_accessory, job_accessory: sage_accessory) }

    describe '.by_job' do
      it 'returns accessories for specified job' do
        expect(CollectionJobAccessory.by_job(warrior_job.id)).to include(warrior_collection)
        expect(CollectionJobAccessory.by_job(warrior_job.id)).not_to include(sage_collection)
      end
    end

    describe '.by_job_accessory' do
      it 'returns collection entries for specified accessory' do
        expect(CollectionJobAccessory.by_job_accessory(warrior_accessory.id)).to include(warrior_collection)
        expect(CollectionJobAccessory.by_job_accessory(warrior_accessory.id)).not_to include(sage_collection)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid collection job accessory' do
      collection_accessory = build(:collection_job_accessory)
      expect(collection_accessory).to be_valid
    end

    it 'creates with associations' do
      collection_accessory = create(:collection_job_accessory)

      aggregate_failures do
        expect(collection_accessory.user).to be_present
        expect(collection_accessory.job_accessory).to be_present
        expect(collection_accessory.job_accessory.job).to be_present
      end
    end
  end

  describe 'blueprint' do
    it 'returns the correct blueprint class' do
      collection_accessory = build(:collection_job_accessory)
      expect(collection_accessory.blueprint).to eq(Api::V1::CollectionJobAccessoryBlueprint)
    end
  end
end