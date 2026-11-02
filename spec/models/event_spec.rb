# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event do
  describe '.advantage_for' do
    # The event element is the boss's; teams bring the advantaged element.
    {
      'Water' => 'Earth',
      'Fire' => 'Water',
      'Earth' => 'Wind',
      'Wind' => 'Fire',
      'Light' => 'Dark',
      'Dark' => 'Light'
    }.each do |boss, team|
      it "maps a #{boss} boss to #{team} teams" do
        expect(described_class.advantage_for(GranblueEnums::ELEMENTS[boss.to_sym]))
          .to eq(GranblueEnums::ELEMENTS[team.to_sym])
      end
    end

    it 'has no advantage for Null or no element' do
      expect(described_class.advantage_for(0)).to be_nil
      expect(described_class.advantage_for(nil)).to be_nil
      expect(build(:event, element: nil).advantage_element).to be_nil
    end
  end

  describe '#banner_key' do
    it "prefers the event's own banner, then its series banner" do
      expect(build(:event, image_key: 'events/abc.png', series: 'dread_barrage').banner_key).to eq('events/abc.png')
      expect(build(:event, series: 'dread_barrage').banner_key).to eq('events/series/dread_barrage.webp')
      expect(build(:event).banner_key).to be_nil
    end

    it "prefers the event's own Japanese banner, then its series' Japanese one" do
      expect(build(:event, image_key_jp: 'events/abc.ja.png', series: 'exo_diablo_crucible').banner_key_jp)
        .to eq('events/abc.ja.png')
      expect(build(:event, series: 'exo_diablo_crucible').banner_key_jp)
        .to eq('events/series/exo_diablo_crucible.ja.webp')
      expect(build(:event, series: nil).banner_key_jp).to be_nil
    end
  end

  describe '.normalize_element' do
    it 'accepts names in any case and integers' do
      expect(described_class.normalize_element('fire')).to eq('Fire')
      expect(described_class.normalize_element(GranblueEnums::ELEMENTS[:Water])).to eq('Water')
      expect(described_class.normalize_element('')).to be_nil
    end
  end

  describe 'validations' do
    it 'requires an element and a unique number among Unite and Fight events' do
      expect(build(:event, :unite_and_fight, element: nil)).not_to be_valid
      expect(build(:event, :dread_barrage, element: nil)).not_to be_valid
      expect(build(:event, kind: :farming, element: nil)).to be_valid
      create(:event, :unite_and_fight, event_number: 70)
      expect(build(:event, :unite_and_fight, event_number: 70)).not_to be_valid
      expect(build(:event, event_number: 70)).to be_valid
    end
  end

  describe '#sticker_half_life and #counting_since' do
    it 'uses half the event length and the earlier of announcement and start' do
      event = create(:event, starts_at: 1.day.from_now, ends_at: 8.days.from_now)
      expect(event.sticker_half_life).to be_within(1).of(3.5.days.to_f)
      expect(event.counting_since).to eq(event.created_at)
    end
  end

  describe 'Guild Wars' do
    let(:jst) { Time.find_zone('Asia/Tokyo') }

    it 'maps JST days to 19:00 on Day 1 and 23:59:59 on the last day' do
      window = described_class.gw_window('2026-09-21', Date.new(2026, 9, 28))
      expect(window[:starts_at]).to eq(jst.local(2026, 9, 21, 19))
      expect(window[:ends_at]).to eq(jst.local(2026, 9, 28, 23, 59, 59))
      expect(window[:starts_at].utc.hour).to eq(10)
    end

    it 'leaves out a blank day and rejects a malformed one' do
      expect(described_class.gw_window(nil, '2026-09-28').keys).to eq([:ends_at])
      expect { described_class.gw_window('soon', nil) }.to raise_error(Date::Error)
    end

    it 'reports its days in JST' do
      event = build(:gw_event, start_date: Date.new(2026, 9, 21), end_date: Date.new(2026, 9, 28))
      expect([event.start_date, event.end_date]).to eq([Date.new(2026, 9, 21), Date.new(2026, 9, 28)])
    end

    it 'knows whether it is upcoming, active or finished' do
      expect(build(:gw_event, :upcoming)).to have_attributes(upcoming?: true, active?: false, finished?: false)
      expect(build(:gw_event, :active)).to have_attributes(upcoming?: false, active?: true, finished?: false)
      expect(build(:gw_event, :finished)).to have_attributes(upcoming?: false, active?: false, finished?: true)
    end

    it 'requires a positive whole number' do
      expect(build(:gw_event, event_number: nil)).not_to be_valid
      expect(build(:gw_event, event_number: 0)).not_to be_valid
      expect(build(:gw_event, event_number: 1.5)).not_to be_valid
      expect(build(:gw_event, event_number: 70)).to be_valid
    end

    it 'finds ones that ended in the last week, by JST day' do
      now = jst.local(2026, 10, 10, 12)
      recent = create(:gw_event, start_date: Date.new(2026, 9, 26), end_date: Date.new(2026, 10, 3))
      create(:gw_event, start_date: Date.new(2026, 9, 25), end_date: Date.new(2026, 10, 2))
      running = create(:gw_event, start_date: Date.new(2026, 10, 5), end_date: Date.new(2026, 10, 12))

      ended = described_class.recently_ended(now: now)
      expect(ended).to include(recent)
      expect(ended.size).to eq(1)
      expect(ended).not_to include(running)
    end

    it "can't be destroyed while crews have scores for it" do
      participation = create(:crew_gw_participation)
      event = participation.event

      expect(event.destroy).to be(false)
      expect(event.errors[:base]).to be_present
      expect(CrewGwParticipation.exists?(participation.id)).to be(true)
    end
  end
end
