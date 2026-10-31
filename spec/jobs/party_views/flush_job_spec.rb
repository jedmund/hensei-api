# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyViews::FlushJob, :party_views do
  # 00:05 JST on the 31st, so ten minutes earlier is still the 30th
  let(:now) { Time.utc(2026, 10, 30, 15, 5) }
  let(:today) { PartyViews::Recorder.date_for(now) }
  let(:yesterday) { today - 1 }
  let(:party) { create(:party, visibility: 1) }
  let(:other) { create(:party, visibility: 1) }

  def record(target, ip, at: now)
    PartyViews::Recorder.record(party_id: target.id, ip: ip, now: at)
  end

  def views(target, date)
    PartyViewDay.find_by(party: target, date: date)&.views
  end

  it "writes each party's unique viewers for today and yesterday" do
    record(party, '198.51.100.1')
    record(party, '198.51.100.2')
    record(party, '198.51.100.2')
    record(other, '198.51.100.1')
    record(other, '198.51.100.1', at: now - 10.minutes)

    described_class.perform_now(now: now)

    expect(views(party, today)).to eq(2)
    expect(views(other, today)).to eq(1)
    expect(views(other, yesterday)).to eq(1)
  end

  it 'is idempotent and picks up later views' do
    record(party, '198.51.100.1')
    described_class.perform_now(now: now)
    described_class.perform_now(now: now)
    expect(PartyViewDay.where(party: party).count).to eq(1)
    expect(views(party, today)).to eq(1)

    record(party, '198.51.100.2')
    described_class.perform_now(now: now)
    expect(views(party, today)).to eq(2)
  end

  it 'never lowers a stored count' do
    PartyViewDay.create!(party: party, date: today, views: 5)
    record(party, '198.51.100.1')

    described_class.perform_now(now: now)

    expect(views(party, today)).to eq(5)
  end

  it 'skips parties deleted since they were viewed' do
    record(party, '198.51.100.1')
    PartyViews::Recorder.record(party_id: SecureRandom.uuid, ip: '198.51.100.1', now: now)

    expect { described_class.perform_now(now: now) }.to change(PartyViewDay, :count).by(1)
  end

  it 'does nothing without views' do
    expect { described_class.perform_now(now: now) }.not_to change(PartyViewDay, :count)
  end
end
