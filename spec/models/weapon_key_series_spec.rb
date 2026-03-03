# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponKeySeries, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:weapon_key) }
    it { is_expected.to belong_to(:weapon_series) }
  end

  describe 'validations' do
    it 'prevents duplicate weapon_key-weapon_series pairs' do
      membership = create(:weapon_key_series)
      duplicate = build(:weapon_key_series,
                        weapon_key: membership.weapon_key,
                        weapon_series: membership.weapon_series)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:weapon_key_id]).to include('has already been taken')
    end

    it 'allows the same weapon key in different series' do
      key = create(:weapon_key)
      series_a = create(:weapon_series)
      series_b = create(:weapon_series)
      create(:weapon_key_series, weapon_key: key, weapon_series: series_a)
      membership = build(:weapon_key_series, weapon_key: key, weapon_series: series_b)
      expect(membership).to be_valid
    end
  end
end
