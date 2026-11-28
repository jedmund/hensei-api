# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::HistoricalBanners', type: :request do
  def jst(text) = ActiveSupport::TimeZone['Asia/Tokyo'].parse(text)

  def banner(kind, pool, starts, ends, items)
    record = HistoricalBanner.create!(key: "#{starts} #{kind}", kind: kind, pool: pool, starts_at: jst(starts),
                                      ends_at: ends && jst(ends), source_key: 'Banner History/2026')
    items.each do |granblue_id, role|
      record.items.create!(granblue_id: granblue_id, item_type: 'Weapon', role: role, wiki_name: granblue_id)
    end
    record
  end

  before do
    banner('summon', 'premium', '2026-11-13 19:00', '2026-11-16 11:59', [%w[1040000001 rate_up], %w[1040000009 featured]])
    banner('flash', 'flash', '2026-11-16 12:00', '2026-11-19 18:59', [%w[1040000002 rate_up], %w[1040000003 zodiac]])
    banner('collab', 'collab', '2026-11-10 17:00', '2026-11-22 20:59', [%w[1040000004 collab], %w[1040000005 pool]])
  end

  it "prefers a stored game banner's own rate-ups, pooled by the wiki banner it matches" do
    game = GachaBanner.create!(game_id: '297520', name: 'Star Premium Draw Set', starts_at: jst('2026-11-16 12:00'),
                               ends_at: jst('2026-11-19 19:00'), fetched_at: Time.current,
                               rarity_rates: { '1' => { '3' => '0.06' } })
    game.rates.create!(tab: 1, reward_id: '1040000007', rarity: 3, category: 'characterWeapon', percent: 0.3, rate_up: true)
    game.rates.create!(tab: 1, reward_id: '1040000008', rarity: 3, category: 'characterWeapon', percent: 0.01)

    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-17', pool: 'flash' }
    expect(response.parsed_body['rate_ups']).to eq(%w[1040000007])
    expect(response.parsed_body['banners'].pluck('kind', 'source')).to eq([%w[flash game]])

    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-17', pool: 'legend' }
    expect(response.parsed_body['rate_ups']).to eq([])
  end

  it 'counts an unmatched 6% game banner for either gala pool' do
    game = GachaBanner.create!(game_id: '300001', name: 'Premium 10-Part Draw', starts_at: jst('2026-12-16 12:00'),
                               ends_at: jst('2026-12-19 19:00'), fetched_at: Time.current,
                               rarity_rates: { '1' => { '3' => '0.06' } })
    game.rates.create!(tab: 1, reward_id: '1040000010', rarity: 3, category: 'characterWeapon', percent: 0.3, rate_up: true)

    %w[flash legend].each do |pool|
      get '/api/v1/gacha/rate_ups', params: { date: '2026-12-17', pool: pool }
      expect(response.parsed_body['rate_ups']).to eq(%w[1040000010])
    end
    get '/api/v1/gacha/rate_ups', params: { date: '2026-12-17', pool: 'premium' }
    expect(response.parsed_body['rate_ups']).to eq([])
  end

  it 'returns a pool banner and its rate-ups, leaving zodiacs out' do
    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-17', pool: 'flash' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['rate_ups']).to eq(%w[1040000002])
    expect(response.parsed_body['banners'].pluck('kind')).to eq(%w[flash])
  end

  it 'takes every main-draw banner that day without a pool, but no collab' do
    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-16' }

    expect(response.parsed_body['banners'].pluck('kind')).to eq(%w[summon flash])
    expect(response.parsed_body['rate_ups']).to eq(%w[1040000001 1040000002])
  end

  it "counts a collab's own items, not the ordinary ones in its pool" do
    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-17', pool: 'collab' }
    expect(response.parsed_body['rate_ups']).to eq(%w[1040000004])
  end

  it 'has nothing for a pool the history lacks' do
    get '/api/v1/gacha/rate_ups', params: { date: '2026-11-17', pool: 'classic' }
    expect(response.parsed_body).to eq('banners' => [], 'rate_ups' => [])
  end

  it 'rejects a date it cannot read' do
    get '/api/v1/gacha/rate_ups', params: { date: 'soon' }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
