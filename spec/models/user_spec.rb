require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:parties).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
    it { should have_many(:collection_characters).dependent(:destroy) }
    it { should have_many(:collection_weapons).dependent(:destroy) }
    it { should have_many(:collection_summons).dependent(:destroy) }
    it { should have_many(:collection_job_accessories).dependent(:destroy) }
    it { should have_many(:collection_artifacts).dependent(:destroy) }
    it { should have_many(:crew_memberships).dependent(:destroy) }
    it { should have_one(:active_crew_membership) }
    it { should have_one(:crew).through(:active_crew_membership) }
  end

  describe 'validations' do
    it { should validate_presence_of(:username) }
    it { should validate_length_of(:username).is_at_least(3).is_at_most(26) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).ignoring_case_sensitivity }
  end

  describe 'collection_privacy enum' do
    it { should define_enum_for(:collection_privacy).with_values(everyone: 1, crew_only: 2, private_collection: 3).with_prefix(true) }

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
      let(:crew) { create(:crew) }

      it 'returns true for crew members' do
        create(:crew_membership, :captain, crew: crew, user: owner)
        create(:crew_membership, crew: crew, user: viewer)
        owner.update(collection_privacy: :crew_only)

        expect(owner.collection_viewable_by?(viewer)).to be true
      end

      it 'returns false for non-crew members' do
        create(:crew_membership, :captain, crew: crew, user: owner)
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
    let(:crew) { create(:crew) }

    it 'returns false when neither user is in a crew' do
      expect(user1.in_same_crew_as?(user2)).to be false
    end

    it 'returns false when only one user is in a crew' do
      create(:crew_membership, :captain, crew: crew, user: user1)
      expect(user1.in_same_crew_as?(user2)).to be false
    end

    it 'returns true when both users are in the same crew' do
      create(:crew_membership, :captain, crew: crew, user: user1)
      create(:crew_membership, crew: crew, user: user2)
      expect(user1.in_same_crew_as?(user2)).to be true
    end

    it 'returns false when users are in different crews' do
      crew2 = create(:crew)
      create(:crew_membership, :captain, crew: crew, user: user1)
      create(:crew_membership, :captain, crew: crew2, user: user2)
      expect(user1.in_same_crew_as?(user2)).to be false
    end

    it 'returns false when other_user is nil' do
      create(:crew_membership, :captain, crew: crew, user: user1)
      expect(user1.in_same_crew_as?(nil)).to be false
    end
  end

  describe '#crew_role' do
    let(:user) { create(:user) }
    let(:crew) { create(:crew) }

    it 'returns nil when user is not in a crew' do
      expect(user.crew_role).to be_nil
    end

    it 'returns captain when user is captain' do
      create(:crew_membership, :captain, crew: crew, user: user)
      expect(user.crew_role).to eq('captain')
    end

    it 'returns vice_captain when user is vice captain' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, :vice_captain, crew: crew, user: user)
      expect(user.crew_role).to eq('vice_captain')
    end

    it 'returns member when user is regular member' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, crew: crew, user: user)
      expect(user.crew_role).to eq('member')
    end
  end

  describe '#crew_officer?' do
    let(:user) { create(:user) }
    let(:crew) { create(:crew) }

    it 'returns false when user is not in a crew' do
      expect(user.crew_officer?).to be false
    end

    it 'returns true for captain' do
      create(:crew_membership, :captain, crew: crew, user: user)
      expect(user.crew_officer?).to be true
    end

    it 'returns true for vice captain' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, :vice_captain, crew: crew, user: user)
      expect(user.crew_officer?).to be true
    end

    it 'returns false for regular member' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, crew: crew, user: user)
      expect(user.crew_officer?).to be false
    end
  end

  describe '#crew_captain?' do
    let(:user) { create(:user) }
    let(:crew) { create(:crew) }

    it 'returns false when user is not in a crew' do
      expect(user.crew_captain?).to be false
    end

    it 'returns true for captain' do
      create(:crew_membership, :captain, crew: crew, user: user)
      expect(user.crew_captain?).to be true
    end

    it 'returns false for vice captain' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, :vice_captain, crew: crew, user: user)
      expect(user.crew_captain?).to be false
    end

    it 'returns false for regular member' do
      create(:crew_membership, :captain, crew: crew)
      create(:crew_membership, crew: crew, user: user)
      expect(user.crew_captain?).to be false
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

  describe '#favorite_parties' do
    it 'returns parties the user has favorited' do
      user = create(:user)
      party1 = create(:party)
      party2 = create(:party)
      create(:favorite, user: user, party: party1)
      create(:favorite, user: user, party: party2)
      expect(user.favorite_parties).to match_array([party1, party2])
    end

    it 'returns empty array when no favorites' do
      user = create(:user)
      expect(user.favorite_parties).to be_empty
    end
  end

  describe 'email normalization' do
    it 'downcases email before save' do
      user = create(:user, email: 'Test@Example.COM')
      expect(user.reload.email).to eq('test@example.com')
    end
  end

  describe 'password validations' do
    it 'requires password on create' do
      user = User.new(username: 'testuser', email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'requires minimum 8 characters' do
      user = User.new(username: 'testuser', email: 'test@example.com',
                       password: 'short', password_confirmation: 'short')
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to match(/too short|minimum/)
    end
  end
end