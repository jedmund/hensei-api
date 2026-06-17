require 'rails_helper'
include ActiveJob::TestHelper

RSpec.describe Party, type: :model do
  describe 'validations' do
    context 'for element' do
      it 'is valid when element is nil' do
        party = build(:party, element: nil)
        expect(party).to be_valid
      end

      it 'is valid when element is one of the allowed values' do
        GranblueEnums::ELEMENTS.values.each do |value|
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

    context 'for master_level' do
      it { should validate_numericality_of(:master_level).only_integer.allow_nil }
      it 'is invalid when master_level is non-integer' do
        party = build(:party, master_level: 'high')
        expect(party).not_to be_valid
        expect(party.errors[:master_level]).to include(/is not a number/)
      end
    end

    context 'for clear_time' do
      it { should validate_numericality_of(:clear_time).only_integer }
      it 'is invalid when clear_time is non-integer' do
        party = build(:party, clear_time: 'fast')
        expect(party).not_to be_valid
        expect(party.errors[:clear_time]).to include(/is not a number/)
      end
    end

    context 'for button_count' do
      it { should validate_numericality_of(:button_count).only_integer.allow_nil }
      it 'is invalid when button_count is non-integer' do
        party = build(:party, button_count: 'ten')
        expect(party).not_to be_valid
        expect(party.errors[:button_count]).to include(/is not a number/)
      end
    end

    context 'for chain_count' do
      it { should validate_numericality_of(:chain_count).only_integer.allow_nil }
      it 'is invalid when chain_count is non-integer' do
        party = build(:party, chain_count: 'two')
        expect(party).not_to be_valid
        expect(party.errors[:chain_count]).to include(/is not a number/)
      end
    end

    context 'for turn_count' do
      it { should validate_numericality_of(:turn_count).only_integer.allow_nil }
      it 'is invalid when turn_count is non-integer' do
        party = build(:party, turn_count: 'five')
        expect(party).not_to be_valid
        expect(party.errors[:turn_count]).to include(/is not a number/)
      end
    end

    context 'for ultimate_mastery' do
      it { should validate_numericality_of(:ultimate_mastery).only_integer.allow_nil }
      it 'is invalid when ultimate_mastery is non-integer' do
        party = build(:party, ultimate_mastery: 'max')
        expect(party).not_to be_valid
        expect(party.errors[:ultimate_mastery]).to include(/is not a number/)
      end
    end

    context 'for visibility' do
      it { should validate_numericality_of(:visibility).only_integer }
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
      expect(parent.remixes.map(&:id)).to match_array([remix1.id, remix2.id])
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
    let(:magna_series) { SummonSeries.find_or_create_by!(slug: 'magna') { |s| s.name_en = 'Magna'; s.name_jp = 'マグナ'; s.order = 2 } }
    let(:optimus_series) { SummonSeries.find_or_create_by!(slug: 'optimus') { |s| s.name_en = 'Optimus'; s.name_jp = 'オプティマス'; s.order = 3 } }
    let(:demi_optimus_series) { SummonSeries.find_or_create_by!(slug: 'demi-optimus') { |s| s.name_en = 'Demi Optimus'; s.name_jp = 'デミ・オプティマス'; s.order = 4 } }
    let(:bellum_series) { SummonSeries.find_or_create_by!(slug: 'bellum') { |s| s.name_en = 'Bellum'; s.name_jp = 'ベルム'; s.order = 18 } }

    # Use real seeded summons, associate with summon_series for testing
    let(:agni) { Summon.find_by!(granblue_id: '2040094000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:hades) { Summon.find_by!(granblue_id: '2040090000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }      # no mod series
    let(:beelzebub) { Summon.find_by!(granblue_id: '2040408000') }    # no mod series
    let(:qilin) { Summon.find_by!(granblue_id: '2040158000') }        # no series

    def add_summon(party, summon, main:, friend:)
      position = main ? -1 : (friend ? 4 : 1)
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

    context 'double sided' do
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

    context 'single sided' do
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

    context 'unboosted' do
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

    context 'missing summon slots' do
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
    let(:magna_series) { SummonSeries.find_or_create_by!(slug: 'magna') { |s| s.name_en = 'Magna'; s.name_jp = 'マグナ'; s.order = 2 } }
    let(:optimus_series) { SummonSeries.find_or_create_by!(slug: 'optimus') { |s| s.name_en = 'Optimus'; s.name_jp = 'オプティマス'; s.order = 3 } }
    let(:agni) { Summon.find_by!(granblue_id: '2040094000').tap { |s| s.update_column(:summon_series_id, optimus_series.id) } }
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }

    def add_summon(party, summon, main:, friend:)
      position = main ? -1 : (friend ? 4 : 1)
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
    let(:magna_series) { SummonSeries.find_or_create_by!(slug: 'magna') { |s| s.name_en = 'Magna'; s.name_jp = 'マグナ'; s.order = 2 } }
    let(:colossus) { Summon.find_by!(granblue_id: '2040034000').tap { |s| s.update_column(:summon_series_id, magna_series.id) } }
    let(:bahamut) { Summon.find_by!(granblue_id: '2040003000') }
    let(:beelzebub) { Summon.find_by!(granblue_id: '2040408000') }

    def add_summon(party, summon, main:, friend:)
      position = main ? -1 : (friend ? 4 : 1)
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
      # Create a party with element 3 (Water) initially.
      party = create(:party, element: 3)
      # Create a dummy weapon (using an instance double) with element 2 (Fire).
      fire_weapon = instance_double('Weapon', element: 2)
      # Create a dummy grid weapon with position -1 and the fire_weapon.
      grid_weapon = instance_double('GridWeapon', position: -1, weapon: fire_weapon)
      allow(party).to receive(:weapons).and_return([grid_weapon])
      # Expect update_column to be called with the new element.
      expect(party).to receive(:update_column).with(:element, 2)
      party.send(:update_element!)
    end

    it 'does not update the party element if no main weapon is found' do
      party = create(:party, element: 3)
      allow(party).to receive(:weapons).and_return([])
      expect(party).not_to receive(:update_column)
      party.send(:update_element!)
    end
  end

  describe '#update_extra!' do
    it 'updates the party extra flag to true if any weapon is in an extra position' do
      party = create(:party, extra: false)
      grid_weapon = instance_double('GridWeapon', position: 9)
      allow(party).to receive(:weapons).and_return([grid_weapon])
      expect(party).to receive(:update_column).with(:extra, true)
      party.send(:update_extra!)
    end

    it 'does not update the party extra flag if no weapon is in an extra position' do
      party = create(:party, extra: false)
      allow(party).to receive(:weapons).and_return([instance_double('GridWeapon', position: 0)])
      expect(party).not_to receive(:update_column)
      party.send(:update_extra!)
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
      expect(party.edit_key).not_to be_nil
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

  describe '#has_orphaned_items?' do
    it 'returns false when party has no grid items' do
      party = create(:party)
      expect(party.has_orphaned_items?).to be false
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

  # Debug block: print debug info if an example fails.
  after(:each) do |example|
    if example.exception
      puts "\nDEBUG [Party Model Validations]: Failed example: #{example.full_description}"
    end
  end
end
