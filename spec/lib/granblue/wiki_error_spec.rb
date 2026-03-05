# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::WikiError do
  it 'inherits from StandardError' do
    expect(described_class).to be < StandardError
  end

  it 'stores code, page, and message' do
    error = described_class.new(code: 'missingtitle', page: 'Zeta', message: 'Page not found')

    aggregate_failures do
      expect(error.to_hash[:code]).to eq('missingtitle')
      expect(error.to_hash[:page]).to eq('Zeta')
      expect(error.to_hash[:message]).to eq('Page not found')
    end
  end

  it 'defaults all fields to nil' do
    error = described_class.new
    expect(error.to_hash).to eq({ message: nil, code: nil, page: nil })
  end

  it 'can be raised and rescued' do
    expect {
      raise described_class.new(code: '404', page: 'Test')
    }.to raise_error(described_class)
  end
end
