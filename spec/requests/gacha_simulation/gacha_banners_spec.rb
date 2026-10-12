require 'rails_helper'

RSpec.describe 'Gacha banner rates', type: :request do
  let(:token) { 'fetcher-token' }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
  let(:items) { gacha_banner_items }

  before do
    travel_to Time.utc(2026, 10, 10)
    Rails.application.config.x.rate_limit_store.clear
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GACHA_RATES_TOKEN').and_return(token)
    allow(GachaSimulation::Catalogue).to receive(:snapshot)
      .and_return({ 'items' => items, 'fingerprint' => 'snapshot', 'loaded_at' => Time.now.to_i })
    allow(GachaSimulation::ExchangeRate).to receive(:quote).and_return(nil)
  end

  describe 'POST /gacha/banners' do
    it 'stores the banner for the fetcher' do
      post '/api/v1/gacha/banners', params: gacha_banner_payload.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('game_id' => '211960', 'items' => 9, 'unmatched' => 9)
      expect(GachaBanner.count).to eq(1)
    end

    it 'refuses a wrong or missing token, and is off without one configured' do
      post '/api/v1/gacha/banners', params: gacha_banner_payload.to_json,
                                    headers: headers.merge('Authorization' => 'Bearer nope')
      expect(response).to have_http_status(:unauthorized)
      post '/api/v1/gacha/banners', params: gacha_banner_payload.to_json, headers: headers.except('Authorization')
      expect(response).to have_http_status(:unauthorized)
      allow(ENV).to receive(:[]).with('GACHA_RATES_TOKEN').and_return(nil)
      post '/api/v1/gacha/banners', params: gacha_banner_payload.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
      expect(GachaBanner.count).to eq(0)
    end

    it 'rejects malformed payloads' do
      post '/api/v1/gacha/banners', params: 'not json', headers: headers
      expect(response).to have_http_status(:bad_request)
      post '/api/v1/gacha/banners', params: { banner: {} }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'the current banner' do
    it 'is only offered once a banner is stored' do
      get '/api/v1/gacha/catalogue'
      expect(response.parsed_body['modes']).not_to include('current')
      GachaSimulation::BannerImport.call(gacha_banner_payload)
      get '/api/v1/gacha/catalogue'
      expect(response.parsed_body['modes'].first).to eq('current')
    end

    it "serves the banner's items, details and rate-ups" do
      GachaSimulation::BannerImport.call(gacha_banner_payload)
      items << gacha_banner_items(['1040999999']).first.merge('identity' => 'Weapon:00000000-0000-0000-0000-000000000999')
      get '/api/v1/gacha/catalogue', params: { mode: 'current' }
      body = response.parsed_body
      expect(body['items'].size).to eq(9)
      expect(body['banner']).to include('game_id' => '211960', 'live' => true)
      expect(body['banner']['rateups']).to eq([{ 'identity' => items.first['identity'], 'percent' => '0.3' }])
    end

    it 'draws with the banner pinned in the result, and replays it after the banner changes' do
      GachaSimulation::BannerImport.call(gacha_banner_payload)
      post '/api/v1/gacha/simulations', params: { mode: 'current', draws: '10', seed: 'fixed' }, as: :json
      expect(response).to have_http_status(:ok)
      first = response.parsed_body
      expect(first['configuration']).to include('mode' => 'current', 'banner' => '211960')
      expect(first['banner']).to include('game_id' => '211960')

      GachaSimulation::BannerImport.call(gacha_banner_payload(id: '212000', start: '2026/10/10 08:00'))
      post '/api/v1/gacha/simulations', params: { mode: 'current', banner: '211960', draws: '10', seed: 'fixed' }, as: :json
      expect(response.parsed_body['ordered']).to eq(first['ordered'])
    end

    it 'refuses custom rate-ups and reports a missing banner' do
      post '/api/v1/gacha/simulations', params: { mode: 'current', draws: '10' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      GachaSimulation::BannerImport.call(gacha_banner_payload)
      post '/api/v1/gacha/simulations',
           params: { mode: 'current', draws: '10', rateups: [{ identity: items.first['identity'], percent: '1' }] }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
