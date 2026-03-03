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
end
