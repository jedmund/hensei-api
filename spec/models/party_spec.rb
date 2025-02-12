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

    context 'for preview_state' do
      # Since preview_state is now an enum, we test valid enum keys.
      it 'allows valid preview_state values via enum' do
        %w[pending queued in_progress generated failed].each do |state|
          party = build(:party, preview_state: state)
          expect(party).to be_valid, "expected preview_state #{state} to be valid"
        end
      end

      it 'is invalid when preview_state is non-numeric and not a valid enum key' do
        expect { build(:party, preview_state: 'active') }
          .to raise_error(ArgumentError, /'active' is not a valid preview_state/)
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

  describe '#ready_for_preview?' do
    it 'returns false if weapons_count is less than 1' do
      party = build(:party, weapons_count: 0, characters_count: 1, summons_count: 1)
      expect(party.ready_for_preview?).to be false
    end

    it 'returns false if characters_count is less than 1' do
      party = build(:party, weapons_count: 1, characters_count: 0, summons_count: 1)
      expect(party.ready_for_preview?).to be false
    end

    it 'returns false if summons_count is less than 1' do
      party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 0)
      expect(party.ready_for_preview?).to be false
    end

    it 'returns true when all counts are at least 1' do
      party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1)
      expect(party.ready_for_preview?).to be true
    end
  end

  describe '#preview_expired?' do
    it 'returns true if preview_generated_at is nil' do
      party = build(:party, preview_generated_at: nil)
      expect(party.preview_expired?).to be true
    end

    it 'returns true if preview_generated_at is older than the expiry period' do
      expired_time = PreviewService::Coordinator::PREVIEW_EXPIRY.ago - 1.minute
      party = build(:party, preview_generated_at: expired_time)
      expect(party.preview_expired?).to be true
    end

    it 'returns false if preview_generated_at is recent' do
      recent_time = Time.current - 1.hour
      party = build(:party, preview_generated_at: recent_time)
      expect(party.preview_expired?).to be false
    end
  end

  describe '#preview_content_changed?' do
    it 'returns true if saved_changes include a preview relevant attribute' do
      party = build(:party)
      # Stub saved_changes so that it includes a key from preview_relevant_attributes (e.g. "name")
      allow(party).to receive(:saved_changes).and_return('name' => ['Old', 'New'])
      expect(party.preview_content_changed?).to be true
    end

    it 'returns false if saved_changes do not include any preview relevant attributes' do
      party = build(:party)
      allow(party).to receive(:saved_changes).and_return('non_relevant' => ['A', 'B'])
      expect(party.preview_content_changed?).to be false
    end
  end

  describe '#should_generate_preview?' do
    context 'when ready_for_preview? is false' do
      it 'returns false regardless of preview_state' do
        party = build(:party, weapons_count: 0, characters_count: 1, summons_count: 1, preview_state: 'pending')
        expect(party.should_generate_preview?).to be false
      end
    end

    context 'when preview_state is nil or pending' do
      it 'returns true' do
        party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1, preview_state: nil)
        expect(party.should_generate_preview?).to be true
        party.preview_state = 'pending'
        expect(party.should_generate_preview?).to be true
      end
    end

    context "when preview_state is 'failed'" do
      it 'returns true if preview_generated_at is more than 5 minutes ago' do
        past_time = 6.minutes.ago
        party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1,
                      preview_state: 'failed', preview_generated_at: past_time)
        expect(party.should_generate_preview?).to be true
      end
    end

    context "when preview_state is 'generated'" do
      it 'returns true if preview is expired' do
        expired_time = PreviewService::Coordinator::PREVIEW_EXPIRY.ago - 1.minute
        party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1,
                      preview_state: 'generated', preview_generated_at: expired_time)
        expect(party.should_generate_preview?).to be true
      end

      it 'returns false if preview is recent and no content change is detected' do
        recent_time = Time.current - 1.minute
        party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1,
                      preview_state: 'generated', preview_generated_at: recent_time)
        allow(party).to receive(:saved_changes).and_return('non_relevant' => ['A', 'B'])
        expect(party.should_generate_preview?).to be false
      end

      it 'returns true if content has changed and preview_generated_at is more than 5 minutes ago' do
        old_time = 6.minutes.ago
        party = build(:party, weapons_count: 1, characters_count: 1, summons_count: 1,
                      preview_state: 'generated', preview_generated_at: old_time)
        allow(party).to receive(:saved_changes).and_return('name' => ['Old', 'New'])
        expect(party.should_generate_preview?).to be true
      end
    end
  end

  describe '#schedule_preview_generation' do
    before(:all) do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'enqueues a GeneratePartyPreviewJob and sets preview_state to "queued" if not already queued or in_progress' do
      # Create a party normally, then force its preview_state to "pending" (the integer value)
      party = create(:party, weapons_count: 1, characters_count: 1, summons_count: 1)
      party.update_column(:preview_state, Party.preview_states[:pending])

      clear_enqueued_jobs
      expect { party.schedule_preview_generation }
        .to have_enqueued_job(GeneratePartyPreviewJob)
              .with(party.id)
      party.reload
      expect(party.preview_state).to eq('queued')
    end

    it 'does nothing if preview_state is already "queued"' do
      party = create(:party, weapons_count: 1, characters_count: 1, summons_count: 1, preview_state: 'queued')
      clear_enqueued_jobs
      expect { party.schedule_preview_generation }.not_to(change { enqueued_jobs.count })
    end

    it 'does nothing if preview_state is "in_progress"' do
      party = create(:party, weapons_count: 1, characters_count: 1, summons_count: 1, preview_state: 'in_progress')
      clear_enqueued_jobs
      expect { party.schedule_preview_generation }.not_to(change { enqueued_jobs.count })
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

  describe '#preview_relevant_attributes' do
    it 'returns an array of expected attribute names' do
      party = build(:party)
      expected = %w[name job_id element weapons_count characters_count summons_count full_auto auto_guard charge_attack clear_time]
      expect(party.send(:preview_relevant_attributes)).to match_array(expected)
    end
  end

  # Debug block: print debug info if an example fails.
  after(:each) do |example|
    if example.exception
      puts "\nDEBUG [Party Model Validations]: Failed example: #{example.full_description}"
    end
  end
end
