# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::SummonTransformer do
  before do
    allow(Rails.logger).to receive_messages(info: nil, debug: nil, error: nil)
  end

  def summon_entry(id: '2040003000', name: 'Bahamut', evolution: 5, level: 200, extras: {})
    entry = {
      'master' => { 'id' => id, 'name' => name },
      'param' => { 'id' => id, 'evolution' => evolution, 'level' => level }
    }
    entry.merge!(extras)
    entry
  end

  describe '#transform' do
    context 'with valid summon data' do
      let(:data) { { '1' => summon_entry } }

      it 'returns array of transformed summons' do
        result = described_class.new(data).transform
        expect(result.length).to eq(1)

        aggregate_failures do
          expect(result[0][:name]).to eq('Bahamut')
          expect(result[0][:id]).to eq('2040003000')
          expect(result[0][:uncap]).to eq(5)
        end
      end
    end

    context 'with non-hash data' do
      it 'returns empty array' do
        expect(described_class.new('string').transform).to eq([])
      end
    end

    context 'with missing master or param' do
      it 'skips entries' do
        data = { '1' => { 'other' => 'data' } }
        expect(described_class.new(data).transform).to eq([])
      end
    end
  end

  describe '1-indexed to 0-indexed positioning' do
    it 'places key "1" at index 0' do
      data = { '1' => summon_entry(name: 'First') }
      result = described_class.new(data).transform
      expect(result[0][:name]).to eq('First')
    end

    it 'preserves ordering with gaps' do
      data = {
        '1' => summon_entry(name: 'First'),
        '3' => summon_entry(name: 'Third')
      }
      result = described_class.new(data).transform
      # After compact: [First, Third] (nil at index 1 removed)
      expect(result.length).to eq(2)
      expect(result[0][:name]).to eq('First')
      expect(result[1][:name]).to eq('Third')
    end
  end

  describe 'quick summon' do
    it 'marks summon as quick summon when id matches' do
      data = { '1' => summon_entry(id: '2040003000') }
      result = described_class.new(data, '2040003000').transform
      expect(result[0][:qs]).to be true
    end

    it 'does not mark when id does not match' do
      data = { '1' => summon_entry(id: '2040003000') }
      result = described_class.new(data, '9999999999').transform
      expect(result[0]).not_to have_key(:qs)
    end

    it 'does not mark when quick_summon_id is nil' do
      data = { '1' => summon_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:qs)
    end
  end

  describe 'sub_aura' do
    it 'includes sub_aura when sub_skill has name' do
      data = { '1' => summon_entry(extras: {
        'sub_skill' => { 'name' => 'Sub Aura Effect' }
      }) }
      result = described_class.new(data).transform
      expect(result[0][:sub_aura]).to eq('Sub Aura Effect')
    end

    it 'excludes sub_aura when sub_skill is absent' do
      data = { '1' => summon_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:sub_aura)
    end
  end

  describe 'transcendence' do
    it 'is 1 at level 200' do
      data = { '1' => summon_entry(level: 200) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(1)
    end

    it 'is 2 at level 211' do
      data = { '1' => summon_entry(level: 211) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(2)
    end

    it 'is 5 at level 241' do
      data = { '1' => summon_entry(level: 241) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(5)
    end
  end
end
