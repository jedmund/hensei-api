# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyStickerSummary do
  let(:party) { create(:party) }
  let(:a) { create(:sticker, slug: 'a', position: 0) }
  let(:b) { create(:sticker, slug: 'b', position: 1) }

  it 'labels ties by picker position' do
    create_list(:party_sticker, 5, party: party, sticker: b)
    create_list(:party_sticker, 5, party: party, sticker: a)
    expect(described_class.labels_for([party.id])).to eq(party.id => %w[a b])
  end

  it 'returns nothing for empty input' do
    expect(described_class.labels_for([])).to eq({})
    expect(described_class.my_stickers_for(nil, [party.id])).to eq({})
  end
end
