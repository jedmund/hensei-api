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
    expect {
      raise described_class.new(file_name: 'test.csv', details: 'bad')
    }.to raise_error(described_class, 'Error importing test.csv: bad')
  end
end

RSpec.describe 'Granblue::Importers.format_attributes' do
  include Granblue::Importers

  it 'formats a hash of attributes' do
    result = format_attributes({ name: 'Sword', rarity: 5 })
    expect(result).to include('name: "Sword"')
    expect(result).to include('rarity: 5')
  end

  it 'formats arrays' do
    result = format_attributes({ elements: %w[fire water] })
    expect(result).to include('elements: ["fire", "water"]')
  end

  it 'formats empty arrays as []' do
    result = format_attributes({ tags: [] })
    expect(result).to include('tags: []')
  end

  it 'formats nil values' do
    result = format_attributes({ series: nil })
    expect(result).to include('series: nil')
  end
end
