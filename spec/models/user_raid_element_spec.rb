# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserRaidElement, type: :model do
  describe 'validations' do
    it 'accepts every game element' do
      GranblueEnums::ELEMENT_ENUM.each_value do |element|
        expect(build(:user_raid_element, element: element)).to be_valid
      end
    end

    it 'rejects Null and out-of-range elements' do
      [GranblueEnums::ELEMENTS[:Null], 7, nil].each do |element|
        record = build(:user_raid_element, element: element)
        expect(record).not_to be_valid
        expect(record.errors[:element]).to be_present
      end
    end

    it 'rejects a duplicate element for the same user and raid' do
      existing = create(:user_raid_element, element: GranblueEnums::ELEMENTS[:Water])
      duplicate = build(:user_raid_element, user: existing.user, raid: existing.raid,
                                            element: GranblueEnums::ELEMENTS[:Water])

      expect(duplicate).not_to be_valid
    end

    it 'allows the same element on another raid or for another user' do
      existing = create(:user_raid_element, element: GranblueEnums::ELEMENTS[:Light])

      expect(build(:user_raid_element, user: existing.user, element: existing.element)).to be_valid
      expect(build(:user_raid_element, raid: existing.raid, element: existing.element)).to be_valid
    end
  end

  describe 'dependents' do
    it 'is removed with its user' do
      record = create(:user_raid_element)
      expect { record.user.destroy! }.to change(described_class, :count).by(-1)
    end

    it 'is removed with its raid' do
      record = create(:user_raid_element)
      expect { record.raid.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
