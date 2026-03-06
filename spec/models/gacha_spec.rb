# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gacha, type: :model do
  it 'creates a valid record with default pool flags' do
    record = create(:gacha)
    expect(record).to be_persisted
    expect(record.premium).to be true
    expect(record.classic).to be false
    expect(record.flash).to be false
    expect(record.legend).to be false
  end

  it 'stores pool flags correctly with multiple traits' do
    record = create(:gacha, :flash, :seasonal_summer)
    expect(record.flash).to be true
    expect(record.summer).to be true
    expect(record.legend).to be false
    expect(record.halloween).to be false
  end

  describe 'polymorphic drawable' do
    it 'associates with a character by default' do
      record = create(:gacha)
      expect(record.drawable_type).to eq('Character')
      expect(record.drawable_id).to be_present
    end

    it 'associates with a weapon via trait' do
      record = create(:gacha, :for_weapon)
      expect(record.drawable_type).to eq('Weapon')
      expect(record.drawable_id).to be_present
    end

    it 'associates with a summon via trait' do
      record = create(:gacha, :for_summon)
      expect(record.drawable_type).to eq('Summon')
      expect(record.drawable_id).to be_present
    end

    it 'has a unique drawable_id index' do
      record = create(:gacha)
      duplicate = build(:gacha, drawable_id: record.drawable_id, drawable_type: record.drawable_type)
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
