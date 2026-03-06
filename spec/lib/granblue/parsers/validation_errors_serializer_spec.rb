# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::ValidationErrorsSerializer do
  let(:record_class) { Struct.new(:name, :errors) }

  let(:error_details) do
    {
      name: [{ error: :blank }],
      element: [{ error: :invalid }, { error: :inclusion }]
    }
  end

  let(:errors) { double('Errors', details: error_details) }
  let(:record) { record_class.new('Test', errors) }

  subject(:result) { described_class.new(record).serialize }

  it 'flattens errors from all fields' do
    expect(result.length).to eq(3)
  end

  it 'serializes each error with field and code' do
    aggregate_failures do
      expect(result[0]).to include(field: 'name', code: 'blank')
      expect(result[1]).to include(field: 'element', code: 'invalid')
      expect(result[2]).to include(field: 'element', code: 'inclusion')
    end
  end

  context 'with no errors' do
    let(:error_details) { {} }

    it 'returns empty array' do
      expect(result).to eq([])
    end
  end
end
