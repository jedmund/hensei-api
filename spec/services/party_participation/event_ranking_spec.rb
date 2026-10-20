# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyParticipation::EventRanking do
  let(:raid) { create(:raid) }
  let(:sticker) { create(:sticker) }
  let(:event) { create(:event, :current, created_at: 3.days.ago) }

  def give(party, at: 1.day.ago)
    create(:party_sticker, party: party, sticker: sticker, user: trusted_user, created_at: at)
  end

  it 'ignores stickers given before the event was announced' do
    old = create(:party, raid: raid, visibility: 1)
    fresh = create(:party, raid: raid, visibility: 1)
    give(old, at: 10.days.ago)
    give(fresh)

    result = described_class.call(raid_ids: [raid.id], window_event: event)
    # `old` has no score in this window, so it only appears as a recent fill.
    expect(result[raid.id]).to eq([fresh.id, old.id])
  end

  it 'tops up raids from the stored score and respects the limit' do
    scored = create(:party, raid: raid, visibility: 1)
    give(scored)
    stored = create_list(:party, 3, raid: raid, visibility: 1)
    stored.each_with_index { |p, i| p.update_columns(participation_score: i + 1) }

    result = described_class.call(raid_ids: [raid.id], window_event: event, limit: 3)
    expect(result[raid.id]).to eq([scored.id, stored[2].id, stored[1].id])
  end

  it 'fills unranked raids with recent public parties of the advantage element only' do
    dark = GranblueEnums::ELEMENTS[:Dark]
    older_dark = create(:party, raid: raid, visibility: 1, element: dark, last_updated: 3.days.ago)
    create(:party, raid: raid, visibility: 1, element: GranblueEnums::ELEMENTS[:Fire], last_updated: 1.day.ago)
    newest_dark = create(:party, raid: raid, visibility: 1, element: dark, last_updated: 1.hour.ago)
    create(:party, raid: raid, visibility: 3, element: dark, last_updated: Time.current)

    result = described_class.call(raid_ids: [raid.id], window_event: nil, element: dark)
    expect(result[raid.id]).to eq([newest_dark.id, older_dark.id])
  end

  it 'returns every raid, even without parties' do
    other = create(:raid)
    expect(described_class.call(raid_ids: [raid.id, other.id], window_event: nil)).to eq(raid.id => [], other.id => [])
  end
end
