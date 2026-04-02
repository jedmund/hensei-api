# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }

    it 'is invalid when end_time is before start_time' do
      event = build(:event, start_time: 2.days.from_now, end_time: 1.day.from_now)
      expect(event).not_to be_valid
      expect(event.errors[:end_time]).to include('must be after start time')
    end

    it 'is invalid when end_time equals start_time' do
      time = 1.day.from_now
      event = build(:event, start_time: time, end_time: time)
      expect(event).not_to be_valid
      expect(event.errors[:end_time]).to include('must be after start time')
    end

    it 'is valid when end_time is after start_time' do
      event = build(:event, start_time: 1.day.from_now, end_time: 3.days.from_now)
      expect(event).to be_valid
    end
  end

  describe 'scopes' do
    let!(:current_event) do
      create(:event, start_time: 1.hour.ago, end_time: 1.hour.from_now)
    end
    let!(:upcoming_event) do
      create(:event, start_time: 1.day.from_now, end_time: 3.days.from_now)
    end
    let!(:past_event) do
      create(:event, start_time: 3.days.ago, end_time: 1.day.ago)
    end

    describe '.current' do
      it 'returns only events happening now' do
        expect(Event.current).to include(current_event)
        expect(Event.current).not_to include(upcoming_event)
        expect(Event.current).not_to include(past_event)
      end
    end

    describe '.upcoming' do
      it 'returns only future events' do
        expect(Event.upcoming).to include(upcoming_event)
        expect(Event.upcoming).not_to include(current_event)
        expect(Event.upcoming).not_to include(past_event)
      end
    end

    describe '.past' do
      it 'returns only finished events' do
        expect(Event.past).to include(past_event)
        expect(Event.past).not_to include(current_event)
        expect(Event.past).not_to include(upcoming_event)
      end
    end
  end

  describe '#status' do
    it 'returns "current" for an ongoing event' do
      event = build(:event, start_time: 1.hour.ago, end_time: 1.hour.from_now)
      expect(event.status).to eq('current')
    end

    it 'returns "upcoming" for a future event' do
      event = build(:event, start_time: 1.day.from_now, end_time: 3.days.from_now)
      expect(event.status).to eq('upcoming')
    end

    it 'returns "past" for a finished event' do
      event = build(:event, start_time: 3.days.ago, end_time: 1.day.ago)
      expect(event.status).to eq('past')
    end
  end
end
