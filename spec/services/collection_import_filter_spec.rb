# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionImportFilter do
  it "takes the game's numbers from element_ids and proficiency_ids as they are" do
    filter = described_class.from('element_ids' => [1, 4], 'proficiency_ids' => ['6'])

    expect(filter.elements).to eq([1, 4])
    expect(filter.proficiencies).to eq([6])
  end

  it 'converts the old numbers that earlier extension builds send as elements and proficiencies' do
    filter = described_class.from(elements: [2, 1], proficiencies: [9, 3])

    expect(filter.elements).to eq([1, 4]) # Fire, Wind
    expect(filter.proficiencies).to eq([6, 4]) # Gun, Axe
  end

  it 'prefers the new keys when a client sends both' do
    filter = described_class.from('element_ids' => [2], 'elements' => [2])

    expect(filter.elements).to eq([2])
  end

  it 'passes an unknown legacy value through, so it still matches nothing rather than widening the scope' do
    expect(described_class.from(elements: [9]).elements).to eq([9])
  end

  it 'is nil when there is nothing to filter by' do
    expect(described_class.from(nil)).to be_nil
    expect(described_class.from({})).to be_nil
    expect(described_class.from('element_ids' => [], 'proficiency_ids' => nil)).to be_nil
    expect(described_class.from('element_ids' => ['x'])).to be_nil
  end
end
