# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobAccessory, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:job) }
  end

  describe 'equality' do
    it 'considers two job accessories with the same id as equal' do
      accessory = create(:job_accessory)
      expect(accessory).to eq(accessory)
    end

    it 'considers two different job accessories as not equal' do
      a = create(:job_accessory)
      b = create(:job_accessory)
      expect(a).not_to eq(b)
    end
  end

  describe 'validations' do
    it 'requires a numeric granblue_id, unique' do
      accessory = create(:job_accessory, granblue_id: '4001')
      expect(build(:job_accessory, granblue_id: 'a1')).not_to be_valid
      expect(build(:job_accessory, granblue_id: accessory.granblue_id)).not_to be_valid
    end

    it 'requires both names and a known type; rarity may be blank' do
      expect(build(:job_accessory, name_en: '')).not_to be_valid
      expect(build(:job_accessory, accessory_type: 0)).not_to be_valid
      expect(build(:job_accessory, rarity: 0)).not_to be_valid
      expect(build(:job_accessory, rarity: nil)).to be_valid
    end
  end
end
