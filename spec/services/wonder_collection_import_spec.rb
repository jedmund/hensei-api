# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WonderCollectionImport do
  let(:user) { create(:user) }

  before { seed_wonder_catalogue! }

  def import(data)
    described_class.new(user, data).call
  end

  def row(granblue_id)
    user.collection_wonders.joins(:wonder).find_by(wonders: { granblue_id: granblue_id })
  end

  describe 'the EN capture' do
    let!(:result) { import(wonder_capture('en')) }

    it 'stores every Wonder' do
      expect(result.as_json).to eq(success: true, created: 51, updated: 0, skipped: [], warnings: [])
      expect(user.collection_wonders.count).to eq(51)
    end

    it 'takes Active from set_flg, with Shield of Eternal Splendor off' do
      expect(row('9003').active).to be(false)
      expect(user.collection_wonders.where(active: false).count).to eq(1)
    end

    it 'stores level and evolution only for leveled Wonders' do
      expect(row('9009')).to have_attributes(level: 20, evolution: 3, possession: nil, image: nil)
      expect(row('1001')).to have_attributes(level: 10, evolution: 0)
      expect(row('9012')).to have_attributes(level: nil, evolution: nil)
      expect(row('1')).to have_attributes(level: nil, evolution: nil)
    end

    it "stores Symbolum's character count and image" do
      symbolum = row('9015')

      expect(symbolum).to have_attributes(possession: 900, image: '9015_10', level: nil)
      expect(symbolum.bonuses).to eq([{ stat: 'dmg_amplify', value: 4 }])
    end

    it 'keeps the imported bonus lines, which match the computed ones' do
      expect(row('9008').imported_bonuses.first).to eq('name' => 'Fire Resistance', 'detail' => '+10%', 'image' => 'bonus_8')
      expect(row('9008').bonuses.first).to eq(stat: 'fire_resistance', value: 10)
    end

    it 'turns a Wonder back on from the all-active capture' do
      result = import(wonder_capture('en.all_active'))

      expect(result.updated).to eq(51)
      expect(row('9003').active).to be(true)
    end
  end

  it 'imports the JA capture the same way (full-width bonus lines match)' do
    result = import(wonder_capture('ja'))

    expect(result.as_json).to include(created: 51, skipped: [], warnings: [])
    expect(row('9003').active).to be(false)
    expect(row('9011')).to have_attributes(level: 20, evolution: 3)
  end

  describe 'the second account (JA)' do
    it "stores Thief's Map, the Hanged Man Ring and Symbolum's image variant" do
      result = import(wonder_capture('ja.account2'))

      expect(result.skipped).to eq([])
      expect(row('9001')).to be_present
      expect(row('2002')).to be_present
      expect(row('9015')).to have_attributes(possession: 835, image: '9015_8')
      expect(row('9015').bonuses).to eq([{ stat: 'dmg_amplify', value: 3.3 }])
      expect(result.warnings).to eq([])
    end

    it 'stores an inactive story Wonder' do
      import(wonder_capture('ja.account2'))

      expect(row('14').active).to be(false)
    end

    it 'leaves a Wonder missing from the payload untouched' do
      memory_book = create(:collection_wonder, user: user, wonder: Wonder.find_by!(granblue_id: '9018'), active: false)
      updated_at = memory_book.updated_at

      import(wonder_capture('ja.account2'))

      expect(memory_book.reload).to have_attributes(active: false, updated_at: updated_at)
    end
  end

  it "imports the third account, with Symbolum's 9015_7 image" do
    result = import(wonder_capture('ja.account3'))

    expect(result.skipped).to eq([])
    expect(result.warnings).to eq([])
    expect(row('2005')).to be_present
    expect(row('9015')).to have_attributes(possession: 756, image: '9015_7')
    expect(row('9015').bonuses).to eq([{ stat: 'dmg_amplify', value: 2.5 }])
  end

  it 'imports the fourth account, with Premium FRIED SHRIMP' do
    result = import(wonder_capture('ja.account4'))

    expect(result.as_json).to include(skipped: [], warnings: [])
    expect(row('9004')).to be_present
  end

  it 'skips and reports a Wonder the catalogue does not know, without adding it' do
    data = wonder_capture('en')
    data.first['item'] << { 'item_id' => '9999', 'name' => 'Not In Catalogue', 'set_flg' => '1', 'category_id' => '1' }

    result = nil
    expect { result = import(data) }.not_to change(Wonder, :count)
    expect(result.skipped).to eq([{ granblue_id: '9999', name: 'Not In Catalogue', reason: 'unknown_wonder' }])
    expect(result.created).to eq(51)
  end

  it 'warns when the imported bonuses differ from the computed ones' do
    data = wonder_capture('en')
    seal = data.flat_map { |c| c['item'] }.find { |i| i['item_id'] == '9008' }
    seal['effective_acquired_bonus'].first['detail'] = '+11%'
    allow(Rails.logger).to receive(:warn)

    result = import(data)

    expect(result.warnings).to eq([{ granblue_id: '9008', reason: 'bonus_mismatch' }])
    expect(Rails.logger).to have_received(:warn).with(/9008 bonuses differ/)
    expect(row('9008')).to be_present
  end

  it 'reports a Wonder whose values are invalid' do
    data = wonder_capture('en')
    data.flat_map { |c| c['item'] }.find { |i| i['item_id'] == '9008' }.merge!('level' => '20', 'evolution' => '0')

    result = import(data)

    expect(result.skipped.first).to include(granblue_id: '9008', reason: 'invalid')
    expect(row('9008')).to be_nil
  end

  it 'rejects a payload that is not a list of categories' do
    expect { import({ 'item' => [] }) }.to raise_error(described_class::InvalidPayload)
    expect { import([{ 'item' => [{ 'name' => 'no id' }] }]) }.to raise_error(described_class::InvalidPayload)
  end
end
