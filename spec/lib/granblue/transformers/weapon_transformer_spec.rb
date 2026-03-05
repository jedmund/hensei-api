# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::WeaponTransformer do
  before do
    allow(Rails.logger).to receive_messages(info: nil, debug: nil, error: nil)
  end

  def weapon_entry(id: '1040007100', name: 'Test Sword', level: 150, series_id: 1, extras: {})
    entry = {
      'master' => { 'id' => id, 'name' => name, 'series_id' => series_id },
      'param' => { 'level' => level }
    }
    entry['param'].merge!(extras)
    entry
  end

  describe '#transform' do
    context 'with valid weapon data' do
      let(:data) { { '1' => weapon_entry } }

      it 'returns array of transformed weapons' do
        result = described_class.new(data).transform
        expect(result.length).to eq(1)

        aggregate_failures do
          expect(result[0][:name]).to eq('Test Sword')
          expect(result[0][:id]).to eq('1040007100')
          expect(result[0][:uncap]).to eq(4) # level 150 > 40,60,80,100 = uncap 4
        end
      end
    end

    context 'with non-hash data' do
      it 'returns empty array' do
        expect(described_class.new('string').transform).to eq([])
      end
    end

    context 'with missing master or param' do
      it 'skips entries without master' do
        data = { '1' => { 'param' => { 'level' => 100 } } }
        expect(described_class.new(data).transform).to eq([])
      end

      it 'skips entries without param' do
        data = { '1' => { 'master' => { 'id' => '1040007100', 'name' => 'Sword' } } }
        expect(described_class.new(data).transform).to eq([])
      end
    end

    context 'with nil master id' do
      it 'skips the weapon' do
        data = { '1' => weapon_entry(id: nil) }
        expect(described_class.new(data).transform).to eq([])
      end
    end
  end

  describe 'uncap level calculation' do
    {
      0 => 0, 39 => 0, 40 => 0, 41 => 1,
      60 => 1, 61 => 2, 80 => 2, 81 => 3,
      100 => 3, 101 => 4, 150 => 4, 151 => 5,
      200 => 5, 201 => 6
    }.each do |level, expected_uncap|
      it "level #{level} -> uncap #{expected_uncap}" do
        data = { '1' => weapon_entry(level: level) }
        result = described_class.new(data).transform
        expect(result[0][:uncap]).to eq(expected_uncap)
      end
    end
  end

  describe 'transcendence' do
    it 'is not added when uncap <= 5' do
      data = { '1' => weapon_entry(level: 200) }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:transcend)
    end

    it 'is 1 at level 201' do
      data = { '1' => weapon_entry(level: 201) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(1)
    end

    it 'is 2 at level 211' do
      data = { '1' => weapon_entry(level: 211) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(2)
    end

    it 'is 5 at level 241' do
      data = { '1' => weapon_entry(level: 241) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(5)
    end
  end

  describe 'multi-element weapons' do
    it 'adjusts id and adds attr for multi-element series' do
      # Series 13 is MULTIELEMENT_SERIES, attribute 2 = element 1
      data = { '1' => weapon_entry(id: '1040007200', series_id: 13) }
      data['1']['master']['attribute'] = 2

      result = described_class.new(data).transform
      aggregate_failures do
        expect(result[0][:attr]).to eq(1) # attribute - 1
        expect(result[0][:id]).to eq('1040007100') # id - (element * 100)
      end
    end

    it 'does not adjust non-multielement series' do
      data = { '1' => weapon_entry(id: '1040007200', series_id: 1) }
      data['1']['master']['attribute'] = 2

      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:attr)
      expect(result[0][:id]).to eq('1040007200')
    end
  end

  describe 'awakening' do
    it 'includes awakening when present' do
      data = { '1' => weapon_entry(extras: {
        'arousal' => { 'is_arousal_weapon' => true, 'form_name' => 'Attack', 'level' => 5 }
      }) }

      result = described_class.new(data).transform
      expect(result[0][:awakening]).to eq({ type: 'Attack', lvl: 5 })
    end

    it 'excludes awakening when not present' do
      data = { '1' => weapon_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:awakening)
    end
  end

  describe 'AX skills' do
    it 'includes ax skills when present' do
      data = { '1' => weapon_entry(extras: {
        'augment_skill_info' => [{ '1' => { 'skill_id' => 123, 'show_value' => '+15%' } }]
      }) }

      result = described_class.new(data).transform
      expect(result[0][:ax]).to eq([{ id: '123', val: '+15%' }])
    end

    it 'excludes ax when not present' do
      data = { '1' => weapon_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:ax)
    end
  end

  describe 'weapon keys' do
    it 'includes keys when skills are present' do
      data = { '1' => weapon_entry }
      data['1']['skill1'] = { 'id' => 'key_1' }
      data['1']['skill2'] = { 'id' => 'key_2' }

      result = described_class.new(data).transform
      expect(result[0][:keys]).to eq(%w[key_1 key_2])
    end

    it 'excludes keys when no skills' do
      data = { '1' => weapon_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:keys)
    end
  end
end
