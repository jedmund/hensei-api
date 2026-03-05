# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::CharacterTransformer do
  before do
    allow(Rails.logger).to receive_messages(info: nil, debug: nil, error: nil)
  end

  def char_entry(id: '3040001000', name: 'Katalina', evolution: 3, extras: {})
    {
      'master' => { 'id' => id, 'name' => name },
      'param' => { 'evolution' => evolution }.merge(extras)
    }
  end

  describe '#transform' do
    context 'with valid character data' do
      let(:data) { { '1' => char_entry } }

      it 'returns array of transformed characters' do
        result = described_class.new(data).transform
        expect(result.length).to eq(1)

        aggregate_failures do
          expect(result[0][:name]).to eq('Katalina')
          expect(result[0][:id]).to eq('3040001000')
          expect(result[0][:uncap]).to eq(3)
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
        data = { '1' => { 'param' => { 'evolution' => 3 } } }
        expect(described_class.new(data).transform).to eq([])
      end
    end

    context 'with nil master id' do
      it 'skips the character' do
        data = { '1' => char_entry(id: nil) }
        expect(described_class.new(data).transform).to eq([])
      end
    end
  end

  describe 'perpetuity rings' do
    it 'sets ringed when has_npcaugment_constant is truthy' do
      data = { '1' => char_entry(extras: { 'has_npcaugment_constant' => true }) }
      result = described_class.new(data).transform
      expect(result[0][:ringed]).to be true
    end

    it 'does not set ringed when absent' do
      data = { '1' => char_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:ringed)
    end
  end

  describe 'transcendence' do
    it 'includes transcend when phase is positive' do
      data = { '1' => char_entry(extras: { 'phase' => 2 }) }
      result = described_class.new(data).transform
      expect(result[0][:transcend]).to eq(2)
    end

    it 'excludes transcend when phase is 0' do
      data = { '1' => char_entry(extras: { 'phase' => 0 }) }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:transcend)
    end

    it 'excludes transcend when phase is absent' do
      data = { '1' => char_entry }
      result = described_class.new(data).transform
      expect(result[0]).not_to have_key(:transcend)
    end
  end

  describe 'multiple characters' do
    it 'transforms all valid entries' do
      data = {
        '1' => char_entry(id: '3040001000', name: 'Katalina', evolution: 3),
        '2' => char_entry(id: '3040002000', name: 'Zeta', evolution: 5)
      }
      result = described_class.new(data).transform
      expect(result.length).to eq(2)
      expect(result.map { |c| c[:name] }).to contain_exactly('Katalina', 'Zeta')
    end
  end
end
