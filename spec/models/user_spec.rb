require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:parties).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_many(:collection_characters).dependent(:destroy) }
    it { should have_many(:collection_weapons).dependent(:destroy) }
    it { should have_many(:collection_summons).dependent(:destroy) }
    it { should have_many(:collection_job_accessories).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:username) }
    it { should validate_length_of(:username).is_at_least(3).is_at_most(26) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).ignoring_case_sensitivity }
  end

  describe 'collection_privacy enum' do
    it { should define_enum_for(:collection_privacy).with_values(everyone: 0, crew_only: 1, private_collection: 2).with_prefix(true) }

    it 'defaults to everyone' do
      user = build(:user)
      expect(user.collection_privacy).to eq('everyone')
    end

    it 'allows setting to crew_only' do
      user = create(:user, collection_privacy: :crew_only)
      expect(user.collection_privacy).to eq('crew_only')
    end

    it 'allows setting to private_collection' do
      user = create(:user, collection_privacy: :private_collection)
      expect(user.collection_privacy).to eq('private_collection')
    end
  end

  describe '#collection_viewable_by?' do
    let(:owner) { create(:user, collection_privacy: :everyone) }
    let(:viewer) { create(:user) }

    context 'when viewer is the owner' do
      it 'returns true regardless of privacy setting' do
        owner.update(collection_privacy: :private_collection)
        expect(owner.collection_viewable_by?(owner)).to be true
      end
    end

    context 'when collection privacy is everyone' do
      it 'returns true for any viewer' do
        owner.update(collection_privacy: :everyone)
        expect(owner.collection_viewable_by?(viewer)).to be true
      end

      it 'returns true for unauthenticated users (nil)' do
        owner.update(collection_privacy: :everyone)
        expect(owner.collection_viewable_by?(nil)).to be true
      end
    end

    context 'when collection privacy is private_collection' do
      it 'returns false for non-owner' do
        owner.update(collection_privacy: :private_collection)
        expect(owner.collection_viewable_by?(viewer)).to be false
      end

      it 'returns false for unauthenticated users' do
        owner.update(collection_privacy: :private_collection)
        expect(owner.collection_viewable_by?(nil)).to be false
      end
    end

    context 'when collection privacy is crew_only' do
      it 'returns false for non-owner (crews not yet implemented)' do
        owner.update(collection_privacy: :crew_only)
        expect(owner.collection_viewable_by?(viewer)).to be false
      end

      it 'returns false for unauthenticated users' do
        owner.update(collection_privacy: :crew_only)
        expect(owner.collection_viewable_by?(nil)).to be false
      end
    end
  end

  describe '#in_same_crew_as?' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it 'returns false (placeholder until crews are implemented)' do
      expect(user1.in_same_crew_as?(user2)).to be false
    end

    it 'returns false when other_user is present' do
      expect(user1.in_same_crew_as?(user2)).to be false
    end
  end

  describe 'collection associations behavior' do
    let(:user) { create(:user) }

    it 'destroys collection_characters when user is destroyed' do
      create(:collection_character, user: user)
      expect { user.destroy }.to change(CollectionCharacter, :count).by(-1)
    end

    it 'destroys collection_weapons when user is destroyed' do
      create(:collection_weapon, user: user)
      expect { user.destroy }.to change(CollectionWeapon, :count).by(-1)
    end

    it 'destroys collection_summons when user is destroyed' do
      create(:collection_summon, user: user)
      expect { user.destroy }.to change(CollectionSummon, :count).by(-1)
    end

    it 'destroys collection_job_accessories when user is destroyed' do
      create(:collection_job_accessory, user: user)
      expect { user.destroy }.to change(CollectionJobAccessory, :count).by(-1)
    end
  end

  describe '#admin?' do
    it 'returns true when role is 9' do
      user = create(:user, role: 9)
      expect(user.admin?).to be true
    end

    it 'returns false when role is not 9' do
      user = create(:user, role: 0)
      expect(user.admin?).to be false
    end
  end
end