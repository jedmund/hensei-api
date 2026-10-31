# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyViews::Recorder, :party_views do
  let(:party_id) { SecureRandom.uuid }
  let(:day) { Time.utc(2026, 10, 31, 12) }

  def seen(date)
    Sidekiq.redis { |r| r.call('SMEMBERS', "#{PartyViewsRedis::PREFIX}:seen:#{date}:#{party_id}") }
  end

  it 'hashes the same IP differently on different days' do
    described_class.record(party_id: party_id, ip: '198.51.100.7', now: day)
    described_class.record(party_id: party_id, ip: '198.51.100.7', now: day + 1.day)

    expect(seen('2026-10-31').first).not_to eq(seen('2026-11-01').first)
  end

  it 'expires its keys' do
    described_class.record(party_id: party_id, ip: '198.51.100.7', now: day)

    ttls = Sidekiq.redis do |r|
      r.call('KEYS', "#{PartyViewsRedis::PREFIX}:*").map { |key| r.call('TTL', key) }
    end
    expect(ttls.size).to eq(3)
    expect(ttls).to all(be_between(1, described_class::TTL))
  end

  it 'returns whether the view was new' do
    expect(described_class.record(party_id: party_id, ip: '198.51.100.7', now: day)).to be(true)
    expect(described_class.record(party_id: party_id, ip: '198.51.100.7', now: day)).to be(false)
    expect(described_class.record(party_id: party_id, now: day)).to be(false)
  end
end
