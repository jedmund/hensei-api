# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Transformers::TransformerError do
  it 'inherits from StandardError' do
    expect(described_class).to be < StandardError
  end

  it 'stores message and details' do
    error = described_class.new('bad data', { field: 'element' })
    expect(error.message).to eq('bad data')
    expect(error.details).to eq({ field: 'element' })
  end

  it 'defaults details to nil' do
    error = described_class.new('oops')
    expect(error.details).to be_nil
  end

  it 'can be raised and rescued' do
    expect {
      raise described_class.new('fail', { row: 5 })
    }.to raise_error(described_class, 'fail')
  end
end
