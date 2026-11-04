# frozen_string_literal: true

require 'rails_helper'
# format_attributes is defined in import_error.rb, which autoloads only with ImportError
require Rails.root.join('lib/granblue/importers/import_error')

RSpec.describe Granblue::Importers, '#format_attributes' do
  include described_class

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
