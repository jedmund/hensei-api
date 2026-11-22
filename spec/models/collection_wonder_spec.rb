# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionWonder do
  let(:user) { create(:user) }
  let(:seal) { create(:wonder, :seal) }
  let(:yupei) { create(:wonder, :yupei) }
  let(:symbolum) { create(:wonder, :symbolum) }
  let(:fixed) { create(:wonder) }

  def row(wonder, **attributes)
    build(:collection_wonder, user: user, wonder: wonder, **attributes)
  end

  describe 'leveled Wonders' do
    it 'caps a Seal level by its evolution' do
      expect(row(seal, level: 10, evolution: 0)).to be_valid
      expect(row(seal, level: 11, evolution: 0)).not_to be_valid
      expect(row(seal, level: 15, evolution: 1)).to be_valid
      expect(row(seal, level: 18, evolution: 2)).to be_valid
      expect(row(seal, level: 19, evolution: 2)).not_to be_valid
      expect(row(seal, level: 20, evolution: 3)).to be_valid
    end

    it 'requires a level of at least 1' do
      expect(row(seal, level: nil)).not_to be_valid
      expect(row(seal, level: 0)).not_to be_valid
    end

    it 'keeps evolution within max_evolution, defaulting to 0' do
      expect(row(seal, level: 5, evolution: 4)).not_to be_valid
      expect(row(seal, level: 5, evolution: -1)).not_to be_valid
      record = row(seal, level: 5)
      expect(record).to be_valid
      expect(record.evolution).to eq(0)
    end

    it "caps a Yupei level by max_level, and it doesn't evolve" do
      expect(row(yupei, level: 10)).to be_valid
      expect(row(yupei, level: 11)).not_to be_valid
      expect(row(yupei, level: 5, evolution: 1)).not_to be_valid
    end

    it 'shows the level image and computes bonuses' do
      record = row(seal, level: 20, evolution: 3)

      expect(record.image_name).to eq("#{seal.granblue_id}_20")
      expect(record.bonuses.first).to eq(stat: 'fire_resistance', value: 10)
    end

    it 'rejects possession' do
      record = row(seal, level: 5, possession: 10)
      expect(record).not_to be_valid
      expect(record.errors[:possession]).to be_present
    end
  end

  describe 'Symbolum' do
    it 'takes a non-negative possession and no level' do
      expect(row(symbolum, possession: 900)).to be_valid
      expect(row(symbolum, possession: -1)).not_to be_valid
      expect(row(symbolum, possession: 900, level: 1)).not_to be_valid
    end

    it 'uses its stored image, or its id' do
      expect(row(symbolum, possession: 900, image: '9015_10').image_name).to eq('9015_10')
      expect(row(symbolum, possession: 900).image_name).to eq('9015')
    end

    it 'only takes images of itself' do
      expect(row(symbolum, image: '9015_8')).to be_valid
      expect(row(symbolum, image: '../9015')).not_to be_valid
      expect(row(symbolum, image: '9008_20')).not_to be_valid
    end
  end

  describe 'fixed Wonders' do
    it 'take none of level, evolution, possession or image' do
      expect(row(fixed)).to be_valid
      %i[level evolution possession].each do |field|
        expect(row(fixed, field => 1)).not_to be_valid
      end
      expect(row(fixed, image: fixed.granblue_id)).not_to be_valid
    end

    it 'shows their id as the image and compute no bonuses' do
      expect(row(fixed).image_name).to eq(fixed.granblue_id)
      expect(row(fixed).bonuses).to eq([])
    end
  end

  it 'holds one row per user and Wonder' do
    create(:collection_wonder, user: user, wonder: fixed)

    expect(row(fixed)).not_to be_valid
    expect(build(:collection_wonder, wonder: fixed)).to be_valid
  end
end
