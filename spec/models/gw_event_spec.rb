require 'rails_helper'

RSpec.describe GwEvent, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:crew_gw_participations).dependent(:destroy) }
    it { is_expected.to have_many(:crews).through(:crew_gw_participations) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:element) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
    it { is_expected.to validate_presence_of(:event_number) }

    describe 'event_number uniqueness' do
      let!(:existing_event) { create(:gw_event, event_number: 100) }

      it 'requires unique event_number' do
        new_event = build(:gw_event, event_number: 100)
        expect(new_event).not_to be_valid
        expect(new_event.errors[:event_number]).to include('has already been taken')
      end
    end

    describe 'end_date_after_start_date' do
      it 'is invalid when end_date is before start_date' do
        event = build(:gw_event, start_date: Date.new(2025, 1, 15), end_date: Date.new(2025, 1, 10))
        expect(event).not_to be_valid
        expect(event.errors[:end_date]).to include('must be after start date')
      end

      it 'is valid when end_date is same as start_date' do
        event = build(:gw_event, start_date: Date.today, end_date: Date.today)
        expect(event).to be_valid
      end

      it 'is valid when end_date is after start_date' do
        event = build(:gw_event, start_date: Date.today, end_date: Date.tomorrow)
        expect(event).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:upcoming_event) { create(:gw_event, :upcoming) }
    let!(:active_event) { create(:gw_event, :active) }
    let!(:finished_event) { create(:gw_event, :finished) }

    describe '.upcoming' do
      it 'returns only upcoming events' do
        expect(GwEvent.upcoming).to include(upcoming_event)
        expect(GwEvent.upcoming).not_to include(active_event)
        expect(GwEvent.upcoming).not_to include(finished_event)
      end
    end

    describe '.current' do
      it 'returns only active events' do
        expect(GwEvent.current).to include(active_event)
        expect(GwEvent.current).not_to include(upcoming_event)
        expect(GwEvent.current).not_to include(finished_event)
      end
    end

    describe '.past' do
      it 'returns only finished events' do
        expect(GwEvent.past).to include(finished_event)
        expect(GwEvent.past).not_to include(upcoming_event)
        expect(GwEvent.past).not_to include(active_event)
      end
    end
  end

  describe '#active?' do
    it 'returns true for active event' do
      event = build(:gw_event, :active)
      expect(event.active?).to be true
    end

    it 'returns false for upcoming event' do
      event = build(:gw_event, :upcoming)
      expect(event.active?).to be false
    end
  end

  describe '#upcoming?' do
    it 'returns true for upcoming event' do
      event = build(:gw_event, :upcoming)
      expect(event.upcoming?).to be true
    end

    it 'returns false for active event' do
      event = build(:gw_event, :active)
      expect(event.upcoming?).to be false
    end
  end

  describe '#finished?' do
    it 'returns true for finished event' do
      event = build(:gw_event, :finished)
      expect(event.finished?).to be true
    end

    it 'returns false for active event' do
      event = build(:gw_event, :active)
      expect(event.finished?).to be false
    end
  end
end
