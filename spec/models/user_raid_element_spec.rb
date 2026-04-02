# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserRaidElement, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      ure = create(:user_raid_element)
      expect(ure.user).to be_a(User)
      expect(ure.user_id).to be_present
    end

    it 'belongs to a raid' do
      ure = create(:user_raid_element)
      expect(ure.raid).to be_a(Raid)
      expect(ure.raid_id).to be_present
    end
  end

  describe 'validations' do
    it 'is valid with element in 1..6' do
      (1..6).each do |el|
        ure = build(:user_raid_element, element: el)
        expect(ure).to be_valid, "expected element #{el} to be valid"
      end
    end

    it 'is invalid with element 0' do
      ure = build(:user_raid_element, element: 0)
      expect(ure).not_to be_valid
      expect(ure.errors[:element]).to be_present
    end

    it 'is invalid with element 7' do
      ure = build(:user_raid_element, element: 7)
      expect(ure).not_to be_valid
      expect(ure.errors[:element]).to be_present
    end

    it 'is invalid without an element' do
      ure = build(:user_raid_element, element: nil)
      expect(ure).not_to be_valid
      expect(ure.errors[:element]).to be_present
    end

    it 'prevents duplicate element for the same user and raid' do
      user = create(:user)
      raid = create(:raid)
      create(:user_raid_element, user: user, raid: raid, element: 1)
      duplicate = build(:user_raid_element, user: user, raid: raid, element: 1)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:element]).to be_present
    end

    it 'allows the same element for different raids' do
      user = create(:user)
      raid_a = create(:raid)
      raid_b = create(:raid)
      create(:user_raid_element, user: user, raid: raid_a, element: 1)
      other = build(:user_raid_element, user: user, raid: raid_b, element: 1)
      expect(other).to be_valid
    end

    it 'allows the same element for different users on the same raid' do
      raid = create(:raid)
      create(:user_raid_element, user: create(:user), raid: raid, element: 3)
      other = build(:user_raid_element, user: create(:user), raid: raid, element: 3)
      expect(other).to be_valid
    end
  end
end
