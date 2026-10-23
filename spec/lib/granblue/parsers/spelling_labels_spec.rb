# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::SpellingLabels do
  after { described_class.reset! }

  it 'knows the shipped spelling-only labels, in any spelling of either name' do
    expect(described_class.spelling?('shield', 'SHIELDED')).to be(true)
    expect(described_class.spelling?('Charge Boost', 'Charge Bar')).to be(true)
    expect(described_class.spelling?('Guilty Break', 'Jammed')).to be(false)
  end

  it 'treats a missing file as nothing listed' do
    expect(described_class.load(Rails.root.join('tmp/no-such-file.json'))).to be_empty
  end
end
