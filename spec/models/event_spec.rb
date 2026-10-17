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

  describe '.normalize_element' do
    it 'accepts names in any case and integers' do
      expect(described_class.normalize_element('fire')).to eq('Fire')
      expect(described_class.normalize_element(3)).to eq('Water')
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
end
