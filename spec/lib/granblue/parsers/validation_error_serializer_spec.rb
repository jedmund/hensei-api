# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::ValidationErrorSerializer do
  let(:record) { Struct.new(:name).new('Test') }
  let(:field) { :name }
  let(:details) { { error: :blank } }

  subject(:result) { described_class.new(record, field, details).serialize }

  it 'returns resource from record class name' do
    expect(result[:resource]).to eq(record.class.to_s)
  end

  it 'returns field as string' do
    expect(result[:field]).to eq('name')
  end

  it 'returns error code as string' do
    expect(result[:code]).to eq('blank')
  end

  context 'with symbol field' do
    let(:field) { :element }

    it 'converts to string' do
      expect(result[:field]).to eq('element')
    end
  end

  context 'with string error code' do
    let(:details) { { error: 'too_long' } }

    it 'returns the string as-is' do
      expect(result[:code]).to eq('too_long')
    end
  end
end
