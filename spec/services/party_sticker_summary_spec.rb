# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyStickerSummary do
  let(:party) { create(:party) }
  let(:a) { create(:sticker, slug: 'a', position: 0) }
  let(:b) { create(:sticker, slug: 'b', position: 1) }

  # Given `minutes_ago` minutes ago, one per giver
  def give(sticker, minutes_ago)
    create(:party_sticker, party: party, sticker: sticker, created_at: minutes_ago.minutes.ago)
  end

  it 'labels with the sticker given most among the last 10' do
    2.times { |i| give(a, i) }
    3.times { |i| give(b, 10 + i) }
    expect(described_class.labels_for([party.id])).to eq(party.id => %w[b])
  end

  it 'ignores stickers older than the last 10, however many' do
    8.times { |i| give(a, 100 + i) }
    3.times { |i| give(b, i) }
    7.times { |i| give(create(:sticker), 10 + i) }
    expect(described_class.labels_for([party.id])).to eq(party.id => %w[b])
  end

  it 'breaks a tie the same way every time' do
    give(a, 1)
    give(b, 2)
    first = described_class.labels_for([party.id])
    expect(first[party.id]).to be_in([%w[a], %w[b]])
    expect(described_class.labels_for([party.id])).to eq(first)
  end

  it 'leaves retired stickers out of the last 10' do
    3.times { |i| give(a, 100 + i) }
    10.times { |i| give(b, i) }
    b.update!(active: false)
    expect(described_class.labels_for([party.id])).to eq(party.id => %w[a])
  end

  it 'returns nothing for empty input' do
    expect(described_class.labels_for([])).to eq({})
    expect(described_class.my_stickers_for(nil, [party.id])).to eq({})
  end
end
