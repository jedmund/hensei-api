# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BannerHistory::Timeline do
  def banner(type, date, **extra)
    { type: type, start_date: Date.iso8601(date), lists: {}, rates: {} }.merge(extra)
  end

  def jst(text) = ActiveSupport::TimeZone['Asia/Tokyo'].parse(text)

  it 'ends each banner the minute before the next starts, with no gaps' do
    timeline = described_class.new([banner('summon', '2026-11-13'), banner('flash', '2026-11-16'),
                                    banner('summon', '2026-11-19')])
    first, gala, last = timeline.main

    expect(first.ends_at).to eq(jst('2026-11-16 11:59'))
    expect(gala.starts_at).to eq(jst('2026-11-16 12:00'))
    expect(gala.ends_at).to eq(jst('2026-11-19 18:59'))
    expect(last.ends_at).to be_nil
  end

  it 'starts galas at 19:00 before 2026-09-16, except the 12-31 Premium Gala' do
    timeline = described_class.new([banner('flash', '2025-12-17'), banner('premium', '2025-12-31'),
                                    banner('character_element', '2026-01-03')])

    expect(timeline.main.map(&:starts_at)).to eq([jst('2025-12-17 19:00'), jst('2025-12-31 12:00'), jst('2026-01-03 19:00')])
  end

  it 'takes a start time the source gives' do
    timeline = described_class.new([banner('legend', '2014-10-31', start_time: '19:05')])
    expect(timeline.main.first.starts_at).to eq(jst('2014-10-31 19:05'))
  end

  it 'runs collabs alongside the main draw with their own end' do
    timeline = described_class.new([banner('flash', '2026-07-16'), banner('premium', '2026-07-31'),
                                    banner('collab', '2026-07-22', name: 'BLEACH', start_time: '17:00',
                                                                   end_date: Date.new(2026, 8, 3), end_time: '20:59')])

    expect(timeline.main.first.ends_at).to eq(jst('2026-07-31 18:59'))
    expect(timeline.collabs.first).to have_attributes(starts_at: jst('2026-07-22 17:00'), ends_at: jst('2026-08-03 20:59'))
    expect(timeline.collabs.first.pool).to eq('collab')
  end

  it 'leaves the end open before a stretch the source does not cover' do
    timeline = described_class.new([banner('premium', '2014-12-31'), banner('character_generic', '2020-01-03')])

    expect(timeline.main.first.ends_at).to be_nil
    expect(timeline.problems).to include('Gap in coverage: 2014-12-31 → 2020-01-03')
  end

  it 'maps banners to the spark maker pools' do
    pools = described_class.new([banner('premium', '2026-10-31'), banner('flash', '2026-11-16'),
                                 banner('summon', '2026-11-19')]).main.map(&:pool)
    expect(pools).to eq(%w[legend flash premium])
  end
end
