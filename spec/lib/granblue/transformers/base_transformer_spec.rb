# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::BaseTransformer do
  before do
    allow(Rails.logger).to receive_messages(info: nil, debug: nil, error: nil)
  end

  describe '#initialize' do
    it 'stores data and options' do
      transformer = described_class.new({ 'key' => 'val' }, language: 'ja')
      expect(transformer.send(:data)).to eq({ 'key' => 'val' })
      expect(transformer.send(:language)).to eq('ja')
    end

    it 'defaults language to en' do
      transformer = described_class.new({})
      expect(transformer.send(:language)).to eq('en')
    end
  end

  describe '#transform' do
    it 'raises NotImplementedError' do
      expect { described_class.new({}).transform }.to raise_error(NotImplementedError)
    end
  end

  describe '#validate_data' do
    it 'returns true for nil data' do
      expect(described_class.new(nil).send(:validate_data)).to be true
    end

    it 'returns true for empty data' do
      expect(described_class.new({}).send(:validate_data)).to be true
    end

    it 'returns true for valid data' do
      expect(described_class.new({ 'a' => 1 }).send(:validate_data)).to be true
    end
  end

  describe '#get_master_param' do
    let(:transformer) { described_class.new({}) }

    it 'extracts master and param from hash' do
      obj = { 'master' => { 'name' => 'Sword' }, 'param' => { 'level' => 100 } }
      master, param = transformer.send(:get_master_param, obj)
      expect(master).to eq({ 'name' => 'Sword' })
      expect(param).to eq({ 'level' => 100 })
    end

    it 'returns [nil, nil] for non-hash' do
      expect(transformer.send(:get_master_param, 'string')).to eq([nil, nil])
    end

    it 'returns nils for hash without master/param' do
      master, param = transformer.send(:get_master_param, { 'other' => 1 })
      expect(master).to be_nil
      expect(param).to be_nil
    end
  end
end
