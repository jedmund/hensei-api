# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    subject { build(:event) }

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

    describe 'slug' do
      it { should validate_uniqueness_of(:slug) }

      it 'is invalid without a slug when name is also blank' do
        event = build(:event, name: nil, slug: nil)
        expect(event).not_to be_valid
        expect(event.errors[:slug]).to include("can't be blank")
      end

      it 'is invalid with uppercase letters' do
        event = build(:event, slug: 'My-Event')
        expect(event).not_to be_valid
        expect(event.errors[:slug]).to include('only allows lowercase letters, numbers, and hyphens')
      end

      it 'is invalid with spaces' do
        event = build(:event, slug: 'my event')
        expect(event).not_to be_valid
      end

      it 'is valid with lowercase letters, numbers, and hyphens' do
        event = build(:event, slug: 'my-event-123')
        expect(event).to be_valid
      end

      it 'auto-generates slug from name when blank' do
        event = build(:event, name: 'Unite and Fight 2026', slug: nil)
        event.valid?
        expect(event.slug).to eq('unite-and-fight-2026')
      end

      it 'does not overwrite an existing slug' do
        event = build(:event, name: 'Unite and Fight', slug: 'custom-slug')
        event.valid?
        expect(event.slug).to eq('custom-slug')
      end
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

  describe '#banner_image_path' do
    it 'returns the path based on slug' do
      event = build(:event, slug: 'unite-and-fight-2026')
      expect(event.banner_image_path).to eq('images/events/unite-and-fight-2026.png')
    end
  end
end
