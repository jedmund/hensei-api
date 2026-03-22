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
    it { should validate_uniqueness_of(:username).case_insensitive }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).ignoring_case_sensitivity }
  end

  describe 'username format validation' do
    it 'allows alphanumeric characters' do
      user = build(:user, username: 'User123')
      expect(user).to be_valid
    end

    it 'allows underscores' do
      user = build(:user, username: 'user_name')
      expect(user).to be_valid
    end

    it 'allows hyphens' do
      user = build(:user, username: 'user-name')
      expect(user).to be_valid
    end

    it 'rejects spaces' do
      user = build(:user, username: 'user name')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include('can only contain letters, numbers, underscores, and hyphens')
    end

    it 'rejects special characters' do
      user = build(:user, username: 'user@name')
      expect(user).not_to be_valid
    end

    it 'rejects dots' do
      user = build(:user, username: 'user.name')
      expect(user).not_to be_valid
    end
  end

  describe 'username profanity filter' do
    it 'rejects an exact offensive word as username' do
      user = build(:user, username: 'asshole')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include('is not available')
    end

    it 'rejects an offensive word as a segment' do
      user = build(:user, username: 'ass-man')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include('is not available')
    end

    it 'rejects an offensive word separated by underscores' do
      user = build(:user, username: 'big_ass_dude')
      expect(user).not_to be_valid
    end

    it 'allows words that contain an offensive substring' do
      user = build(:user, username: 'class')
      expect(user).to be_valid
    end

    it 'allows assassin (contains ass as substring but not as segment)' do
      user = build(:user, username: 'assassin')
      expect(user).to be_valid
    end
  end

  describe 'username reserved words' do
    it 'rejects admin' do
      user = build(:user, username: 'admin')
      expect(user).not_to be_valid
      expect(user.errors[:username]).to include('is not available')
    end

    it 'rejects system (case-insensitive)' do
      user = build(:user, username: 'System')
      expect(user).not_to be_valid
    end

    it 'allows normal usernames' do
      user = build(:user, username: 'jedmund')
      expect(user).to be_valid
    end
  end

  describe 'display_name profanity filter' do
    it 'rejects offensive English display names' do
      user = build(:user, display_name: 'asshole')
      expect(user).not_to be_valid
      expect(user.errors[:display_name]).to include('contains inappropriate language')
    end

    it 'rejects offensive Japanese display names' do
      # Use a word from the JA list
      user = build(:user, display_name: 'アナル')
      expect(user).not_to be_valid
      expect(user.errors[:display_name]).to include('contains inappropriate language')
    end

    it 'allows clean display names' do
      user = build(:user, display_name: 'グランブルー太郎')
      expect(user).to be_valid
    end
  end

  describe 'username grandfathering' do
    it 'allows legacy users to save non-username fields without format validation' do
      user = create(:user)
      user.update_column(:username_migrated, false)
      user.update_column(:username, 'legacy user!')
      user.reload

      expect(user.update(element: 'fire')).to be true
    end

    it 'validates format when a legacy user changes their username' do
      user = create(:user)
      user.update_column(:username_migrated, false)
      user.reload

      expect(user.update(username: 'invalid name!')).to be false
      expect(user.errors[:username]).to include('can only contain letters, numbers, underscores, and hyphens')
    end

    it 'flips username_migrated when a legacy user changes to a valid username' do
      user = create(:user)
      user.update_column(:username_migrated, false)
      user.reload

      expect(user.update(username: 'valid-name')).to be true
      expect(user.reload.username_migrated).to be true
    end

    it 'sets username_migrated to true for new users' do
      user = create(:user)
      expect(user.username_migrated).to be true
    end
  end

  describe 'display_name' do
    it 'validates length minimum' do
      user = build(:user, display_name: 'ab')
      expect(user).not_to be_valid
      expect(user.errors[:display_name].join).to match(/too short/)
    end

    it 'validates length maximum' do
      user = build(:user, display_name: 'a' * 27)
      expect(user).not_to be_valid
    end

    it 'allows nil display_name' do
      user = build(:user, display_name: nil)
      expect(user).to be_valid
    end

    it 'allows blank display_name' do
      user = build(:user, display_name: '')
      expect(user).to be_valid
    end

    it 'allows any characters including unicode' do
      user = build(:user, display_name: 'グランブルー太郎')
      expect(user).to be_valid
    end
  end

  describe '#display_name_or_username' do
    it 'returns display_name when present' do
      user = build(:user, username: 'jedmund', display_name: 'Jed')
      expect(user.display_name_or_username).to eq('Jed')
    end

    it 'returns username when display_name is nil' do
      user = build(:user, username: 'jedmund', display_name: nil)
      expect(user.display_name_or_username).to eq('jedmund')
    end

    it 'returns username when display_name is blank' do
      user = build(:user, username: 'jedmund', display_name: '')
      expect(user.display_name_or_username).to eq('jedmund')
    end
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

  describe '#generate_reset_token!' do
    let(:user) { create(:user) }

    it 'returns a token that can be verified' do
      raw_token = user.generate_reset_token!
      expect(user.reset_token_valid?(raw_token)).to be true
    end

    it 'generates different tokens on successive calls' do
      first_token = user.generate_reset_token!
      second_token = user.generate_reset_token!
      expect(first_token).not_to eq(second_token)
    end

    it 'invalidates the previous token when a new one is generated' do
      first_token = user.generate_reset_token!
      user.generate_reset_token!
      expect(user.reset_token_valid?(first_token)).to be false
    end
  end

  describe '#reset_token_valid?' do
    let(:user) { create(:user) }

    it 'returns false when no token has been generated' do
      expect(user.reset_token_valid?('anything')).to be false
    end

    it 'returns false for a wrong token' do
      user.generate_reset_token!
      expect(user.reset_token_valid?('wrong-token')).to be false
    end

    it 'returns false after the token expires' do
      raw_token = user.generate_reset_token!
      travel_to(61.minutes.from_now) do
        expect(user.reset_token_valid?(raw_token)).to be false
      end
    end

    it 'returns true just before expiry' do
      raw_token = user.generate_reset_token!
      travel_to(59.minutes.from_now) do
        expect(user.reset_token_valid?(raw_token)).to be true
      end
    end
  end

  describe '#clear_reset_token!' do
    let(:user) { create(:user) }

    it 'makes a previously valid token invalid' do
      raw_token = user.generate_reset_token!
      user.clear_reset_token!
      expect(user.reset_token_valid?(raw_token)).to be false
    end
  end

  describe '#reset_token_cooldown?' do
    let(:user) { create(:user) }

    it 'returns true immediately after generating a token' do
      user.generate_reset_token!
      expect(user.reset_token_cooldown?).to be true
    end

    it 'returns false after the cooldown period' do
      user.generate_reset_token!
      travel_to(3.minutes.from_now) do
        expect(user.reset_token_cooldown?).to be false
      end
    end
  end
end