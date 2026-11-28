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
    banner('summon', 'premium', '2026-11-13 19:00', '2026-11-16 11:59', [%w[1040000001 featured]])
    banner('flash', 'flash', '2026-11-16 12:00', '2026-11-19 18:59', [%w[1040000002 rate_up], %w[1040000003 zodiac]])
    banner('collab', 'collab', '2026-11-10 17:00', '2026-11-22 20:59', [%w[1040000004 collab], %w[1040000005 pool]])
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
