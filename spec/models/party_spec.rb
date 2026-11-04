require 'rails_helper'

RSpec.describe Party, type: :model do
  include ActiveJob::TestHelper

  describe 'validations' do
    describe 'element' do
      it 'is valid when element is nil' do
        party = build(:party, element: nil)
        expect(party).to be_valid
      end

      it 'is valid when element is one of the allowed values' do
        GranblueEnums::ELEMENTS.each_value do |value|
          party = build(:party, element: value)
          expect(party).to be_valid, "expected element #{value} to be valid"
        end
      end

      it 'is invalid when element is not one of the allowed values' do
        party = build(:party, element: 7)
        expect(party).not_to be_valid
        expect(party.errors[:element]).to include(/must be one of/)
      end

      it 'is invalid when element is not an integer' do
        party = build(:party, element: 'fire')
        expect(party).not_to be_valid
        expect(party.errors[:element]).to include(/is not a number/)
      end
    end

    describe 'master_level' do
      it { is_expected.to validate_numericality_of(:master_level).only_integer.allow_nil }

      it 'is invalid when master_level is non-integer' do
        party = build(:party, master_level: 'high')
        expect(party).not_to be_valid
        expect(party.errors[:master_level]).to include(/is not a number/)
      end
    end

    describe 'clear_time' do
      it { is_expected.to validate_numericality_of(:clear_time).only_integer }

      it 'is invalid when clear_time is non-integer' do
        party = build(:party, clear_time: 'fast')
        expect(party).not_to be_valid
        expect(party.errors[:clear_time]).to include(/is not a number/)
      end
    end

    describe 'button_count' do
      it { is_expected.to validate_numericality_of(:button_count).only_integer.allow_nil }

      it 'is invalid when button_count is non-integer' do
        party = build(:party, button_count: 'ten')
        expect(party).not_to be_valid
        expect(party.errors[:button_count]).to include(/is not a number/)
      end
    end

    describe 'chain_count' do
      it { is_expected.to validate_numericality_of(:chain_count).only_integer.allow_nil }

      it 'is invalid when chain_count is non-integer' do
        party = build(:party, chain_count: 'two')
        expect(party).not_to be_valid
        expect(party.errors[:chain_count]).to include(/is not a number/)
      end
    end

    describe 'turn_count' do
      it { is_expected.to validate_numericality_of(:turn_count).only_integer.allow_nil }

      it 'is invalid when turn_count is non-integer' do
        party = build(:party, turn_count: 'five')
        expect(party).not_to be_valid
        expect(party.errors[:turn_count]).to include(/is not a number/)
      end
    end

    describe 'ultimate_mastery_level' do
      it { is_expected.to validate_numericality_of(:ultimate_mastery_level).only_integer.allow_nil }

      it 'is invalid when ultimate_mastery_level is non-integer' do
        party = build(:party, ultimate_mastery_level: 'max')
        expect(party).not_to be_valid
        expect(party.errors[:ultimate_mastery_level]).to include(/is not a number/)
      end

      it 'keeps ultimate_mastery as a compatibility alias' do
        party = build(:party, ultimate_mastery: 1)
        expect(party.ultimate_mastery_level).to eq(1)
        expect(party.ultimate_mastery).to eq(1)
      end
    end

    describe 'visibility' do
      it { is_expected.to validate_numericality_of(:visibility).only_integer }

      it 'is valid when visibility is one of 1, 2, or 3' do
        [1, 2, 3].each do |value|
          party = build(:party, visibility: value)
          expect(party).to be_valid, "expected visibility #{value} to be valid"
        end
      end

      it 'is invalid when visibility is not in [1, 2, 3]' do
        party = build(:party, visibility: 0)
        expect(party).not_to be_valid
        expect(party.errors[:visibility]).to include(/must be 1 \(Public\), 2 \(Unlisted\), or 3 \(Private\)/)
      end

      it 'is invalid when visibility is non-integer' do
        party = build(:party, visibility: 'public')
        expect(party).not_to be_valid
        expect(party.errors[:visibility]).to include(/is not a number/)
      end
    end
  end

  describe '#is_remix' do
    context 'when source_party is nil' do
      it 'returns false' do
        party = build(:party, source_party: nil)
        expect(party.remix?).to be false
      end
    end

    context 'when source_party is present' do
      it 'returns true' do
        parent = create(:party)
        remix = build(:party, source_party: parent)
        expect(remix.remix?).to be true
      end
    end
  end

  describe '#remixes' do
    it 'returns all parties whose source_party_id equals the party id' do
      parent = create(:party)
      remix1 = create(:party, source_party: parent)
      remix2 = create(:party, source_party: parent)
      expect(parent.remixes.map(&:id)).to contain_exactly(remix1.id, remix2.id)
    end
  end

  describe 'Visibility helpers (#public?, #unlisted?, #private?)' do
    it 'returns public? true when visibility is 1' do
      party = build(:party, visibility: 1)
      expect(party.public?).to be true
      expect(party.unlisted?).to be false
      expect(party.private?).to be false
    end

    it 'returns unlisted? true when visibility is 2' do
      party = build(:party, visibility: 2)
      expect(party.unlisted?).to be true
      expect(party.public?).to be false
      expect(party.private?).to be false
    end

    it 'returns private? true when visibility is 3' do
      party = build(:party, visibility: 3)
      expect(party.private?).to be true
      expect(party.public?).to be false
      expect(party.unlisted?).to be false
    end
  end

  describe '#is_favorited' do
    let(:user) { create(:user) }

    it 'returns false if the passed user is nil' do
      party = build(:party)
      expect(party.favorited?(nil)).to be false
    end

    it 'returns true if the party is favorited by the user' do
      party = create(:party)
      create(:favorite, user: user, party: party)
      Rails.cache.clear
      expect(party.favorited?(user)).to be true
    end

    it 'returns false if the party is not favorited by the user' do
      party = create(:party)
      Rails.cache.clear
      expect(party.favorited?(user)).to be false
    end
  end

  describe '#mod_and_side' do
    # Create summon series for testing
    let(:magna_series) do
      SummonSeries.find_or_create_by!(slug: 'magna') do |s|
        s.name_en = 'Magna'
        s.name_jp = 'マグナ'
        s.order = 2
      end
    end
    let(:optimus_series) do
      SummonSeries.find_or_create_by!(slug: 'optimus') do |s|
        s.name_en = 'Optimus'
        s.name_jp = 'オプティマス'
        s.order = 3
      end
    end
    let(:demi_optimus_series) do
      SummonSeries.find_or_create_by!(slug: 'demi-optimus') do |s|
        s.name_en = 'Demi Optimus'
        s.name_jp = 'デミ・オプティマス'
        s.order = 4
      end
    end
    let(:bellum_series) do
      SummonSeries.find_or_create_by!(slug: 'bellum') do |s|
        s.name_en = 'Bellum'
        s.name_jp = 'ベルム'
        s.order = 18
      end
    end

    # Use real seeded summons, associate with summon_series for testing
    let(:agni) { Summon.find_by!(granblue_id: '2040094000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:hades) { Summon.find_by!(granblue_id: '2040090000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }      # no mod series
    let(:beelzebub) { Summon.find_by!(granblue_id: '2040408000') }    # no mod series
    let(:qilin) { Summon.find_by!(granblue_id: '2040158000') }        # no series

    def add_summon(party, summon, main:, friend:)
      position = if main
                   -1
                 elsif friend
                   4
                 else
                   1
                 end
      GridSummon.create!(
        party: party,
        summon: summon,
        position: position,
        main: main,
        friend: friend,
        uncap_level: 3,
        transcendence_step: 0
      )
    end

    context 'when double sided' do
      it 'returns double primal with two real Primal summons (Agni + Hades)' do
        party = create(:party)
        add_summon(party, agni, main: true, friend: false)
        add_summon(party, hades, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('primal')
        expect(result[:side]).to eq('double')
      end

      it 'returns double omega with two Omega summons in both slots' do
        party = create(:party)
        add_summon(party, colossus, main: true, friend: false)

        beelzebub.update_column(:summon_series_id, magna_series.id)
        add_summon(party, beelzebub, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('omega')
        expect(result[:side]).to eq('double')
      ensure
        beelzebub.update_column(:summon_series_id, nil)
      end

      it 'returns double odious when both summons are bellum series' do
        party = create(:party)
        bahamut.update_column(:summon_series_id, bellum_series.id)
        beelzebub.update_column(:summon_series_id, bellum_series.id)
        add_summon(party, bahamut, main: true, friend: false)
        add_summon(party, beelzebub, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('odious')
        expect(result[:side]).to eq('double')
      ensure
        bahamut.update_column(:summon_series_id, nil)
        beelzebub.update_column(:summon_series_id, nil)
      end

      it 'treats demi-optimus as primal for double' do
        party = create(:party)
        add_summon(party, agni, main: true, friend: false)
        bahamut.update_column(:summon_series_id, demi_optimus_series.id)
        add_summon(party, bahamut, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('primal')
        expect(result[:side]).to eq('double')
      ensure
        bahamut.update_column(:summon_series_id, nil)
      end
    end

    context 'when single sided' do
      it 'returns single primal when main is Agni and friend is Bahamut' do
        party = create(:party)
        add_summon(party, agni, main: true, friend: false)
        add_summon(party, bahamut, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('primal')
        expect(result[:side]).to eq('single')
      end

      it 'returns single omega when main is Colossus and friend is Bahamut' do
        party = create(:party)
        add_summon(party, colossus, main: true, friend: false)
        add_summon(party, bahamut, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('omega')
        expect(result[:side]).to eq('single')
      end

      it 'uses main summon type when main is Primal and friend is Omega' do
        party = create(:party)
        add_summon(party, agni, main: true, friend: false)
        add_summon(party, colossus, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('primal')
        expect(result[:side]).to eq('single')
      end

      it 'uses friend type when main is non-mod and friend is Primal' do
        party = create(:party)
        add_summon(party, bahamut, main: true, friend: false)
        add_summon(party, hades, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('primal')
        expect(result[:side]).to eq('single')
      end
    end

    context 'when unboosted' do
      it 'returns unboosted when both summons are non-mod types' do
        party = create(:party)
        add_summon(party, bahamut, main: true, friend: false)
        add_summon(party, beelzebub, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('unboosted')
        expect(result[:side]).to eq('none')
      end

      it 'returns unboosted when both summons have no summon series' do
        party = create(:party)
        add_summon(party, qilin, main: true, friend: false)
        add_summon(party, bahamut, main: false, friend: true)
        party.reload

        result = party.mod_and_side
        expect(result[:mod]).to eq('unboosted')
        expect(result[:side]).to eq('none')
      end
    end

    context 'when summon slots are missing' do
      it 'returns nil when party has no summons' do
        party = create(:party)
        expect(party.mod_and_side).to be_nil
      end

      it 'returns nil when only main summon is set (no friend)' do
        party = create(:party)
        add_summon(party, agni, main: true, friend: false)
        party.reload

        expect(party.mod_and_side).to be_nil
      end

      it 'returns nil when only friend summon is set (no main)' do
        party = create(:party)
        add_summon(party, agni, main: false, friend: true)
        party.reload

        expect(party.mod_and_side).to be_nil
      end
    end
  end

  describe '#recompute_boost!' do
    let(:magna_series) do
      SummonSeries.find_or_create_by!(slug: 'magna') do |s|
        s.name_en = 'Magna'
        s.name_jp = 'マグナ'
        s.order = 2
      end
    end
    let(:optimus_series) do
      SummonSeries.find_or_create_by!(slug: 'optimus') do |s|
        s.name_en = 'Optimus'
        s.name_jp = 'オプティマス'
        s.order = 3
      end
    end
    let(:agni) { Summon.find_by!(granblue_id: '2040094000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }

    def add_summon(party, summon, main:, friend:)
      position = if main
                   -1
                 elsif friend
                   4
                 else
                   1
                 end
      GridSummon.create!(party: party, summon: summon, position: position, main: main, friend: friend, uncap_level: 3, transcendence_step: 0)
    end

    it 'persists boost_mod to the database' do
      party = create(:party)
      add_summon(party, agni, main: true, friend: false)
      add_summon(party, bahamut, main: false, friend: true)
      party.reload

      party.recompute_boost!
      expect(party.reload.boost_mod).to eq('primal')
    end

    it 'sets boost_mod to nil when summon slots are incomplete' do
      party = create(:party)
      add_summon(party, agni, main: true, friend: false)
      party.reload

      party.recompute_boost!
      expect(party.reload.boost_mod).to be_nil
    end
  end

  describe '#recompute_side!' do
    let(:magna_series) do
      SummonSeries.find_or_create_by!(slug: 'magna') do |s|
        s.name_en = 'Magna'
        s.name_jp = 'マグナ'
        s.order = 2
      end
    end
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }
    let(:beelzebub) { Summon.find_by!(granblue_id: '2040408000') }

    def add_summon(party, summon, main:, friend:)
      position = if main
                   -1
                 elsif friend
                   4
                 else
                   1
                 end
      GridSummon.create!(party: party, summon: summon, position: position, main: main, friend: friend, uncap_level: 3, transcendence_step: 0)
    end

    it 'persists boost_side to the database' do
      party = create(:party)
      add_summon(party, colossus, main: true, friend: false)
      add_summon(party, bahamut, main: false, friend: true)
      party.reload

      party.recompute_side!
      expect(party.reload.boost_side).to eq('single')
    end

    it 'stores none when both summons are non-mod' do
      party = create(:party)
      add_summon(party, bahamut, main: true, friend: false)
      add_summon(party, beelzebub, main: false, friend: true)
      party.reload

      party.recompute_side!
      expect(party.reload.boost_side).to eq('none')
    end
  end

  describe '#update_element!' do
    it 'updates the party element if a main weapon (position -1) with a different element is present' do
      # Create a party with element 2 (Water) initially.
      party = create(:party, element: 2)
      # Create a dummy weapon (using an instance double) with element 1 (Fire).
      fire_weapon = instance_double(Weapon, element: 1)
      # Create a dummy grid weapon with position -1 and the fire_weapon.
      grid_weapon = instance_double(GridWeapon, position: -1, weapon: fire_weapon)
      allow(party).to receive(:weapons).and_return([grid_weapon])
      allow(party).to receive(:update_column)
      party.send(:update_element!)
      expect(party).to have_received(:update_column).with(:element, 1)
    end

    it 'does not update the party element if no main weapon is found' do
      party = create(:party, element: 2)
      allow(party).to receive(:weapons).and_return([])
      allow(party).to receive(:update_column)
      party.send(:update_element!)
      expect(party).not_to have_received(:update_column)
    end
  end

  describe '#update_extra!' do
    it 'updates the party extra flag to true if any weapon is in an extra position' do
      party = create(:party, extra: false)
      grid_weapon = instance_double(GridWeapon, position: 9)
      allow(party).to receive(:weapons).and_return([grid_weapon])
      allow(party).to receive(:update_column)
      party.send(:update_extra!)
      expect(party).to have_received(:update_column).with(:extra, true)
    end

    it 'does not update the party extra flag if no weapon is in an extra position' do
      party = create(:party, extra: false)
      allow(party).to receive(:weapons).and_return([instance_double(GridWeapon, position: 0)])
      allow(party).to receive(:update_column)
      party.send(:update_extra!)
      expect(party).not_to have_received(:update_column)
    end
  end

  describe '#set_shortcode' do
    it 'sets a shortcode of length 6' do
      party = build(:party, shortcode: nil)
      party.send(:set_shortcode)
      expect(party.shortcode.length).to eq(6)
    end
  end

  describe '#set_edit_key' do
    it 'sets edit_key for an anonymous party (when user is nil)' do
      party = build(:party, user: nil, edit_key: nil)
      party.send(:set_edit_key)
      expect(party.edit_key).to match(/\A\h{32}\z/)
    end

    it 'keeps an existing edit_key' do
      legacy_key = 'a' * 40
      party = build(:party, user: nil, edit_key: legacy_key)
      party.send(:set_edit_key)
      expect(party.edit_key).to eq(legacy_key)
    end

    it 'does not set edit_key when a user is present' do
      party = build(:party, user: create(:user), edit_key: nil)
      party.send(:set_edit_key)
      expect(party.edit_key).to be_nil
    end
  end

  describe '#random_string' do
    it 'returns an alphanumeric string of length 6 by default' do
      party = build(:party)
      str = party.send(:random_string)
      expect(str.length).to eq(6)
      expect(str).to match(/\A[a-zA-Z0-9]+\z/)
    end
  end

  describe '#viewable_by?' do
    let(:owner) { create(:user) }
    let(:viewer) { create(:user) }

    it 'returns true for public parties regardless of user' do
      party = create(:party, user: owner, visibility: 1)
      expect(party.viewable_by?(nil)).to be true
      expect(party.viewable_by?(viewer)).to be true
    end

    it 'returns true for unlisted parties' do
      party = create(:party, user: owner, visibility: 2)
      expect(party.viewable_by?(viewer)).to be true
    end

    it 'returns true for the party owner even when private' do
      party = create(:party, user: owner, visibility: 3)
      expect(party.viewable_by?(owner)).to be true
    end

    it 'returns false for a non-owner on a private party' do
      party = create(:party, user: owner, visibility: 3)
      expect(party.viewable_by?(viewer)).to be false
    end

    it 'returns false for nil user on a private party' do
      party = create(:party, user: owner, visibility: 3)
      expect(party.viewable_by?(nil)).to be false
    end

    it 'returns true for an admin with admin_mode on a private party' do
      admin = create(:user, role: 9)
      party = create(:party, user: owner, visibility: 3)
      expect(party.viewable_by?(admin, admin_mode: true)).to be true
    end

    it 'returns false for an admin without admin_mode on a private party' do
      admin = create(:user, role: 9)
      party = create(:party, user: owner, visibility: 3)
      expect(party.viewable_by?(admin)).to be false
    end
  end

  describe '.viewable_by' do
    let(:owner) { create(:user) }
    let(:stranger) { create(:user) }
    let(:admin) { create(:user, role: 9) }
    let(:crew) { create(:crew) }
    let(:other_crew) { create(:crew) }
    let(:crewmate) { create(:user).tap { |u| create(:crew_membership, crew: crew, user: u) } }
    let(:other_crew_member) { create(:user).tap { |u| create(:crew_membership, crew: other_crew, user: u) } }

    let!(:public_party) { create(:party, user: owner, visibility: 1) }
    let!(:unlisted_party) { create(:party, user: owner, visibility: 2) }
    let!(:private_party) { create(:party, user: owner, visibility: 3) }
    let!(:shared_party) do
      create(:party, user: owner, visibility: 3).tap do |party|
        create(:party_share, party: party, shareable: crew, shared_by: owner)
      end
    end

    let(:parties) { [public_party, unlisted_party, private_party, shared_party] }

    def expect_agreement(viewer, admin_mode: false)
      visible_ids = Party.viewable_by(viewer, admin_mode: admin_mode).where(id: parties.map(&:id)).pluck(:id)
      parties.each do |party|
        expect(visible_ids.include?(party.id)).to eq(party.viewable_by?(viewer, admin_mode: admin_mode)),
                                                  "disagreement on visibility #{party.visibility} " \
                                                  "(shared: #{party == shared_party})"
      end
      visible_ids
    end

    it 'matches #viewable_by? for an anonymous viewer' do
      expect(expect_agreement(nil)).to contain_exactly(public_party.id, unlisted_party.id)
    end

    it 'matches #viewable_by? for the owner' do
      expect(expect_agreement(owner)).to match_array(parties.map(&:id))
    end

    it 'matches #viewable_by? for a stranger with no crew' do
      expect(expect_agreement(stranger)).to contain_exactly(public_party.id, unlisted_party.id)
    end

    it 'matches #viewable_by? for a member of the crew the party is shared with' do
      expect(expect_agreement(crewmate)).to contain_exactly(public_party.id, unlisted_party.id, shared_party.id)
    end

    it 'matches #viewable_by? for a member of a different crew' do
      expect(expect_agreement(other_crew_member)).to contain_exactly(public_party.id, unlisted_party.id)
    end

    it 'matches #viewable_by? for a retired member of the shared crew' do
      retired = create(:user)
      create(:crew_membership, :retired, crew: crew, user: retired)
      expect(expect_agreement(retired)).to contain_exactly(public_party.id, unlisted_party.id)
    end

    it 'matches #viewable_by? for an admin outside admin mode' do
      expect(expect_agreement(admin)).to contain_exactly(public_party.id, unlisted_party.id)
    end

    it 'matches #viewable_by? for an admin in admin mode' do
      expect(expect_agreement(admin, admin_mode: true)).to match_array(parties.map(&:id))
    end

    it 'composes onto an association scope' do
      remix = create(:party, user: stranger, source_party: public_party, remix: true, visibility: 3)
      create(:party, user: stranger, source_party: private_party, remix: true, visibility: 1)

      expect(public_party.remixes.viewable_by(nil)).to be_empty
      expect(public_party.remixes.viewable_by(stranger)).to contain_exactly(remix)
    end
  end

  describe '#shared_with_crew?' do
    it 'returns false when crew is nil' do
      party = create(:party)
      expect(party.shared_with_crew?(nil)).to be false
    end

    it 'returns false when no party_share exists' do
      party = create(:party)
      crew = create(:crew)
      expect(party.shared_with_crew?(crew)).to be false
    end
  end

  describe '#orphaned_items?' do
    it 'returns false when party has no grid items' do
      party = create(:party)
      expect(party.orphaned_items?).to be false
    end
  end

  describe 'video_url validation' do
    it 'accepts a valid YouTube URL' do
      party = build(:party, video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
      expect(party).to be_valid
    end

    it 'accepts a youtu.be short URL' do
      party = build(:party, video_url: 'https://youtu.be/dQw4w9WgXcQ')
      expect(party).to be_valid
    end

    it 'rejects an invalid URL' do
      party = build(:party, video_url: 'https://vimeo.com/12345')
      expect(party).not_to be_valid
      expect(party.errors[:video_url]).to include('must be a valid YouTube URL')
    end

    it 'allows blank video_url' do
      party = build(:party, video_url: '')
      expect(party).to be_valid
    end
  end

  describe 'skills_are_unique validation' do
    it 'is valid when all skills are different' do
      skill_a = create(:job_skill)
      skill_b = create(:job_skill)
      party = build(:party, skill0: skill_a, skill1: skill_b)
      expect(party).to be_valid
    end

    it 'is invalid when duplicate skills are assigned' do
      skill = create(:job_skill)
      party = build(:party, skill0: skill, skill1: skill)
      expect(party).not_to be_valid
      expect(party.errors[:job_skills]).to include('must be unique')
    end
  end

  describe 'guidebooks_are_unique validation' do
    it 'is valid when all guidebooks are different' do
      gb1 = create(:guidebook)
      gb2 = create(:guidebook)
      party = build(:party, guidebook1: gb1, guidebook2: gb2)
      expect(party).to be_valid
    end

    it 'is invalid when duplicate guidebooks are assigned' do
      gb = create(:guidebook)
      party = build(:party, guidebook1: gb, guidebook2: gb)
      expect(party).not_to be_valid
      expect(party.errors[:guidebooks]).to include('must be unique')
    end
  end

  describe 'full_auto_skills validation' do
    it 'is valid when empty' do
      expect(build(:party, full_auto_skills: {})).to be_valid
    end

    it 'is valid with known slots and boolean values' do
      expect(build(:party, full_auto_skills: { '0' => true, '3' => false })).to be_valid
    end

    it 'rejects a value that is not an object' do
      party = build(:party, full_auto_skills: %w[0 1])
      expect(party).not_to be_valid
      expect(party.errors[:full_auto_skills]).to eq(['must be an object'])
    end

    it 'rejects an unknown slot' do
      party = build(:party, full_auto_skills: { '4' => true })
      expect(party).not_to be_valid
      expect(party.errors[:full_auto_skills]).to eq(['invalid slot 4'])
    end

    it 'rejects a non-boolean value' do
      party = build(:party, full_auto_skills: { '0' => 'maybe' })
      expect(party).not_to be_valid
      expect(party.errors[:full_auto_skills]).to eq(['invalid value for slot 0'])
    end
  end

  describe 'error order across the custom validations' do
    it 'reports skills, guidebooks and full auto errors in declaration order' do
      skill = create(:job_skill)
      guidebook = create(:guidebook)
      party = build(:party, skill0: skill, skill1: skill, guidebook1: guidebook, guidebook2: guidebook,
                            full_auto_skills: { '9' => true }, visibility: 4)

      expect(party).not_to be_valid
      expect(party.errors.attribute_names).to eq(%i[skill1 job_skills guidebook2 guidebooks full_auto_skills visibility])
    end
  end

  describe 'visibility and crew sharing' do
    let(:owner) { create(:user) }
    let(:crew) { create(:crew) }
    let(:crewmate) { create(:user).tap { |u| create(:crew_membership, crew: crew, user: u) } }
    let(:outsider) { create(:user).tap { |u| create(:crew_membership, crew: create(:crew), user: u) } }
    let(:party) do
      create(:party, user: owner, visibility: 3).tap do |p|
        create(:party_share, party: p, shareable: crew, shared_by: owner)
      end
    end

    it 'is shared with the crew it was shared to' do
      expect(party.shared_with_crew?(crew)).to be true
    end

    it 'is not shared with another crew' do
      expect(party.shared_with_crew?(create(:crew))).to be false
    end

    it 'lets a member of the shared crew view a private party' do
      expect(party.viewable_by?(crewmate)).to be true
    end

    it 'hides a private shared party from a member of another crew' do
      expect(party.viewable_by?(outsider)).to be false
    end

    it 'hides a private shared party from anonymous viewers' do
      expect(party.viewable_by?(nil)).to be false
    end

    it 'builds the anonymous scope from visibility alone' do
      expect(described_class.viewable_by(nil).to_sql).to eq(described_class.where(visibility: [1, 2]).to_sql)
    end

    it 'gives admins in admin mode an unfiltered scope' do
      admin = create(:user, role: 9)
      expect(described_class.viewable_by(admin, admin_mode: true).to_sql).to eq(described_class.all.to_sql)
    end
  end

  describe '.quality_name_sql' do
    it 'excludes every default name, quoted' do
      quoted = described_class::LOW_QUALITY_NAMES.map { |name| "'#{name}'" }.join(',')
      expect(described_class.quality_name_sql).to eq("LOWER(parties.name) NOT IN (#{quoted})")
    end

    it 'lists the default names and up to five remixes of each' do
      expect(described_class::LOW_QUALITY_NAMES.size).to eq(33)
      expect(described_class::LOW_QUALITY_NAMES).to include(
        'untitled', '無題', 'new team', 'remix of remix of remix of remix of remix of new team',
        '無題のリミックスのリミックスのリミックスのリミックスのリミックス'
      )
      expect(described_class::LOW_QUALITY_NAMES).not_to include('remix of remix of remix of remix of remix of remix of untitled')
    end
  end

  describe '.quality' do
    let!(:good) { create(:party, :complete, name: 'Fire Grid') }

    it 'keeps a named, filled team with an owner' do
      expect(described_class.quality).to contain_exactly(good)
    end

    it 'drops teams without an owner' do
      create(:party, :complete, user: nil, name: 'Anonymous Grid')
      expect(described_class.quality).to contain_exactly(good)
    end

    it 'drops default names case-insensitively, and teams with no name' do
      ['Untitled', 'Remix of New Team', '無題のリミックス', 'NEW TEAM', nil].each do |name|
        create(:party, :complete, name: name)
      end
      expect(described_class.quality).to contain_exactly(good)
    end

    it 'keeps a name that only contains a default one' do
      named = create(:party, :complete, name: 'Untitled Water')
      expect(described_class.quality).to contain_exactly(good, named)
    end

    it 'drops teams below the weapon or summon minimum' do
      create(:party, name: 'Few Weapons', weapons_count: 4, summons_count: 2)
      create(:party, name: 'Few Summons', weapons_count: 5, summons_count: 1)
      expect(described_class.quality).to contain_exactly(good)
    end

    it 'exempts Evoking Solomonis teams from the minimums' do
      solomonis = create(:party, :solomonis, name: 'Expedition', weapons_count: 3, summons_count: 1)
      expect(described_class.quality).to contain_exactly(good, solomonis)
    end
  end

  describe '.rising_rank_sql' do
    it 'decays the participation score by the team age' do
      now = Time.utc(2026, 1, 1)
      expect(described_class.rising_rank_sql(now)).to eq(
        'parties.participation_score * POWER(0.5, ' \
        "GREATEST(EXTRACT(EPOCH FROM ('2026-01-01 00:00:00' - parties.created_at)), 0) / 1209600) DESC"
      )
    end
  end

  describe '.rising' do
    let(:now) { Time.utc(2026, 6, 1, 12) }

    def team(score, age, visibility: 1)
      create(:party, visibility: visibility).tap do |party|
        party.update_columns(participation_score: score, created_at: now - age)
      end
    end

    it 'ranks public teams by score halved every 14 days of age, then by id' do
      fresh = team(10, 0.days)
      tied = team(10, 0.days)
      older = team(16, 14.days)
      future = team(5, -1.day)
      low = team(4, 0.days)
      oldest = team(40, 42.days)

      # Ids are UUIDs, so equal ranks come back in UUID order.
      expected = [*[fresh, tied].sort_by(&:id), older, *[future, oldest].sort_by(&:id), low]
      expect(described_class.rising(now: now).to_a).to eq(expected)
    end

    it 'leaves out teams that are not public or have no score' do
      shown = team(1, 0.days)
      team(100, 0.days, visibility: 2)
      team(100, 0.days, visibility: 3)
      team(0, 0.days)
      create(:party, visibility: 1)

      expect(described_class.rising(now: now).to_a).to eq([shown])
    end

    it 'composes with the quality bar' do
      kept = create(:party, :complete, name: 'Wind Grid').tap { |p| p.update_columns(participation_score: 2) }
      create(:party, name: 'Sparse Grid').tap { |p| p.update_columns(participation_score: 5) }

      expect(described_class.quality.rising(now: now).to_a).to eq([kept])
    end
  end

  describe '#keep_only_collection_links_of!' do
    let(:owner) { create(:user) }
    let(:other) { create(:user) }
    let(:owned_weapon) { create(:collection_weapon, user: owner) }
    let(:foreign_weapon) { create(:collection_weapon, user: other) }
    let(:owned_summon) { create(:collection_summon, user: owner) }
    let(:owned_character) { create(:collection_character, user: owner) }
    let(:owned_artifact) { create(:collection_artifact, user: owner) }

    let(:party) do
      create(:party, user: owner, collection_source_user_id: owner.id).tap do |p|
        create(:grid_weapon, party: p, weapon: owned_weapon.weapon, collection_weapon: owned_weapon, position: 0)
        create(:grid_weapon, party: p, weapon: foreign_weapon.weapon, collection_weapon: foreign_weapon,
                             position: 1, orphaned: true)
        gc = create(:grid_character, party: p, character: owned_character.character, collection_character: owned_character)
        create(:grid_summon, party: p, summon: owned_summon.summon, collection_summon: owned_summon)
        create(:grid_artifact, grid_character: gc, artifact: owned_artifact.artifact, element: 'fire',
                               collection_artifact: owned_artifact)
      end
    end

    let(:copy) { described_class.includes(all_characters: :grid_artifact).find(party.id) }

    def links(target)
      {
        source: target.collection_source_user_id,
        weapons: target.all_weapons.sort_by(&:position).map { |w| [w.collection_weapon_id, w.orphaned] },
        characters: target.all_characters.map(&:collection_character_id),
        summons: target.all_summons.map { |s| [s.collection_summon_id, s.orphaned] },
        artifacts: target.all_characters.filter_map(&:grid_artifact).map { |a| [a.collection_artifact_id, a.orphaned] }
      }
    end

    it "keeps the user's own links and drops the rest, clearing their orphaned flag" do
      copy.keep_only_collection_links_of!(owner)

      expect(links(copy)).to eq(
        source: owner.id,
        weapons: [[owned_weapon.id, false], [nil, false]],
        characters: [owned_character.id],
        summons: [[owned_summon.id, false]],
        artifacts: [[owned_artifact.id, false]]
      )
    end

    it "drops every link for another user's copy" do
      copy.keep_only_collection_links_of!(other)

      expect(links(copy)).to eq(
        source: nil,
        weapons: [[nil, false], [foreign_weapon.id, true]],
        characters: [nil],
        summons: [[nil, false]],
        artifacts: [[nil, false]]
      )
    end

    it 'drops every link for a copy without a user' do
      copy.keep_only_collection_links_of!(nil)

      expect(links(copy)).to eq(
        source: nil,
        weapons: [[nil, false], [nil, false]],
        characters: [nil],
        summons: [[nil, false]],
        artifacts: [[nil, false]]
      )
    end

    it 'changes nothing in the database' do
      copy.keep_only_collection_links_of!(nil)
      expect(links(described_class.find(party.id))[:weapons]).to eq([[owned_weapon.id, false], [foreign_weapon.id, true]])
    end
  end

  describe 'difficulty recompute' do
    let!(:party) { create(:party) }

    it 'enqueues a recompute when a team is created' do
      expect { create(:party) }.to have_enqueued_job(PartyDifficulty::ScoreJob)
    end

    it 'enqueues a recompute when a scoring column changes' do
      expect { party.update!(weapons_count: 3) }.to have_enqueued_job(PartyDifficulty::ScoreJob).with(party.id)
      expect { party.update!(job: create(:job)) }.to have_enqueued_job(PartyDifficulty::ScoreJob).with(party.id)
      expect { party.update!(ultimate_mastery_level: 2) }.to have_enqueued_job(PartyDifficulty::ScoreJob).with(party.id)
    end

    it 'skips the recompute for edits that do not affect the score' do
      expect { party.update!(name: 'Renamed', description: nil) }.not_to have_enqueued_job(PartyDifficulty::ScoreJob)
    end

    it 'enqueues a recompute from mark_updated!' do
      expect { party.mark_updated! }.to have_enqueued_job(PartyDifficulty::ScoreJob).with(party.id)
    end

    it 'lists the scoring columns' do
      expect(described_class::SCORING_COLUMNS).to eq(
        %w[weapons_count characters_count summons_count job_id accessory_id ultimate_mastery_level]
      )
    end
  end

  describe 'callback chains' do
    def chain(name)
      described_class.public_send(name).map { |callback| [callback.kind, callback.filter] }
                     .select { |_kind, filter| filter.is_a?(Symbol) && !filter.start_with?('autosave_associated_records') }
    end

    it 'runs the commit hooks in their declared order' do
      expect(chain(:_commit_callbacks)).to eq(
        [%i[after update_element!], %i[after update_extra!], %i[after enqueue_difficulty_recompute_if_scoring_changed!]]
      )
    end

    it 'runs the create hooks in their declared order' do
      expect(chain(:_create_callbacks)).to eq(
        [%i[after create_remapped_substitutions], %i[before set_shortcode], %i[before set_edit_key]]
      )
    end

    it 'runs the custom validations after the association validations' do
      validations = chain(:_validate_callbacks).map(&:last)
      expect(validations.last(3)).to eq(%i[skills_are_unique guidebooks_are_unique validate_full_auto_skills])
      expect(validations.index(:solomonis_consistency)).to be < validations.index(:validate_associated_records_for_remixes)
    end
  end
end
