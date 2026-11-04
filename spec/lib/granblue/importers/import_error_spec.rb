# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Importers::ImportError do
  it 'inherits from StandardError' do
    expect(described_class).to be < StandardError
  end

  it 'builds message from file_name and details' do
    error = described_class.new(file_name: 'weapons.csv', details: 'Missing column: name_en')

    aggregate_failures do
      expect(error.message).to eq('Error importing weapons.csv: Missing column: name_en')
      expect(error.file_name).to eq('weapons.csv')
      expect(error.details).to eq('Missing column: name_en')
    end
  end

  it 'can be raised and rescued' do
    expect do
      raise described_class.new(file_name: 'test.csv', details: 'bad')
    end.to raise_error(described_class, 'Error importing test.csv: bad')
  end
end
