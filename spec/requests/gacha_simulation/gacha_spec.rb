require 'rails_helper'

RSpec.describe 'Gacha API', type: :request do
  let(:items) do
    categories = %w[characterWeapon weapon summon]
    (1..3).flat_map do |rarity|
      categories.each_with_index.map do |category, index|
        type = category == 'summon' ? 'Summon' : 'Weapon'
        { 'identity' => "#{type}:00000000-0000-0000-0000-#{format('%012d', (rarity * 10) + index)}",
          'drawable_type' => type, 'category' => category, 'rarity' => rarity, 'promotions' => [1],
          'name' => { 'en' => category, 'ja' => category }, 'granblue_id' => ((rarity * 10) + index).to_s }
      end
    end
  end
  let(:snapshot) { { 'items' => items, 'fingerprint' => 'snapshot', 'loaded_at' => Time.now.to_i } }
  let(:store) { {} }
  let(:redis) { double('redis') }

  before do
    Rails.application.config.x.rate_limit_store.clear
    allow(GachaSimulation::Catalogue).to receive(:snapshot).and_return(snapshot)
    allow(GachaSimulation::ExchangeRate).to receive(:quote).and_return(nil)
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:get) { |key| store[key] }
    allow(redis).to receive(:set) { |key, value, **options| store[key] = value unless options[:xx] && !store.key?(key) }
    allow(GachaSimulation::SimulationJob).to receive(:perform_async)
  end

  it 'serves searchable typed items without authentication' do
    get '/api/v1/gacha/catalogue', params: { q: 'summon' }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['items'].size).to eq(3)
    expect(response.parsed_body['seasons']).to include('formal')
  end

  it 'draws, serializes counts, and replays' do
    input = { draws: '10', seed: 'fixed' }
    post '/api/v1/gacha/simulations', params: input, as: :json
    expect(response).to have_http_status(:ok)
    first = response.parsed_body
    expect(first['draws']).to eq('10')
    expect(first['ordered'].size).to eq(10)
    post '/api/v1/gacha/simulations', params: input, as: :json
    expect(response.parsed_body).to eq(first)
  end

  it 'queues captured distributions, completes jobs and expires tokens' do
    post '/api/v1/gacha/simulations', params: { draws: '10010', seed: 'queued' }, as: :json
    expect(response).to have_http_status(:accepted)
    token = response.parsed_body['token']
    expect(token).to match(/\A[0-9a-f]{48}\z/)
    expect(GachaSimulation::Jobs.read(token)['compiled']['fingerprint']).to eq('snapshot')
    allow(GachaSimulation::Catalogue).to receive(:snapshot).and_raise('must not recapture')
    GachaSimulation::SimulationJob.new.perform(token)
    get "/api/v1/gacha/jobs/#{token}"
    expect(response.parsed_body['status']).to eq('complete')
    expect(response.parsed_body.dig('result', 'ordered')).to be_nil
    expect(response.parsed_body.dig('result', 'draws')).to eq('10010')
    store.clear
    GachaSimulation::SimulationJob.new.perform(token)
    get "/api/v1/gacha/jobs/#{token}"
    expect(response).to have_http_status(:not_found)
  end

  it 'enforces computation throttling independently of general log mode' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GACHA_REQUESTS_PER_MINUTE', '60').and_return('1')
    2.times { post '/api/v1/gacha/simulations', params: { draws: '10' }, as: :json }
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After']).to eq('60')
    get '/api/v1/gacha/catalogue'
    expect(response).to have_http_status(:ok)
  end

  it 'returns validation and catalogue-unavailable errors' do
    post '/api/v1/gacha/simulations', params: { draws: '11' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    allow(GachaSimulation::Catalogue).to receive(:snapshot).and_raise(GachaSimulation::Unavailable, 'Unavailable')
    get '/api/v1/gacha/catalogue'
    expect(response).to have_http_status(:service_unavailable)
  end

  it 'calculates odds and Until using typed targets and requested copies' do
    target = items.find { |i| i['rarity'] == 3 }['identity']
    post '/api/v1/gacha/odds', params: { target: target, copies: 4, draws: '300', rateups: [{ identity: target, percent: '0.3' }] }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['probability']).to be_within(1e-9).of(0.013303125)
    post '/api/v1/gacha/until', params: { target: target, copies: 4, seed: 'fixed' }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['copies'].to_i).to be >= 4
    expect(response.parsed_body['draws'].to_i % 10).to eq(0)
  end
end
