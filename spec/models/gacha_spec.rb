# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gacha, type: :model do
  it 'creates a valid record' do
    record = create(:gacha)
    expect(record).to be_persisted
  end

  it 'stores pool flags' do
    record = create(:gacha, :flash, :seasonal_summer)
    expect(record.flash).to be true
    expect(record.summer).to be true
    expect(record.legend).to be false
  end

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
end
