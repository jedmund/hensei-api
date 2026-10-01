# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'General API rate limits', type: :request do
  let(:search_body) { { search: { locale: 'en' } }.to_json }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  def search(headers = {})
    post '/api/v1/search/characters', params: search_body, headers: json_headers.merge(headers)
  end

  context 'with small limits' do
    before do
      stub_const('ApiRateLimits::RULES', [
        { name: 'search/minute', limit: 2, period: 1.minute, path: ApiRateLimits::SEARCH_PATH }
      ])
    end

    after { ApiRateLimits.define!(enforce: false) }

    context 'when enforcing' do
      before { ApiRateLimits.define!(enforce: true) }

      it 'returns a JSON 429 once a client is over the limit' do
        2.times do
          search('CF-Connecting-IP' => '203.0.113.9')
          expect(response).to have_http_status(:ok)
        end

        search('CF-Connecting-IP' => '203.0.113.9')
        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers['Retry-After']).to eq('60')
        expect(response.parsed_body['error']).to be_present
      end

      it 'counts clients separately by real IP' do
        2.times { search('CF-Connecting-IP' => '203.0.113.9') }

        search('CF-Connecting-IP' => '198.51.100.7')
        expect(response).to have_http_status(:ok)
      end

      it 'does not limit paths outside the rule' do
        3.times { get '/api/v1/raids', headers: { 'CF-Connecting-IP' => '203.0.113.9' } }
        expect(response.status).not_to eq(429)
      end
    end

    context 'when only logging' do
      before { ApiRateLimits.define!(enforce: false) }

      it 'lets requests through and logs the first one over the limit' do
        allow(Rails.logger).to receive(:warn).and_call_original

        3.times { search('CF-Connecting-IP' => '203.0.113.9') }
        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:warn).with(%r{\[rate_limit\] would_block rule=search/minute key=203\.0\.113\.9})
      end
    end
  end

  describe 'bot probes' do
    it 'answers scanner paths with 404 before routing, in log mode too' do
      ['/wp-login.php', '/wp-admin/install.php', '/.env', '/.git/config', '/api/v1/whatever/x.php',
       '/sitemap.xml'].each do |path|
        get path
        expect(response).to have_http_status(:not_found), "expected #{path} to be blocked"
        expect(response.parsed_body['error']).to eq('Not found')
      end
    end

    it 'does not block normal API paths' do
      get '/api/v1/raids'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'per-token limit' do
    let(:token) do
      Doorkeeper::AccessToken.create!(resource_owner_id: create(:user).id, expires_in: 30.days, scopes: 'public').token
    end

    before do
      stub_const('ApiRateLimits::RULES', [])
      allow(ApiRateLimits).to receive(:token_limit).and_return(2)
      ApiRateLimits.define!(enforce: true)
    end

    after { ApiRateLimits.define!(enforce: false) }

    it 'limits each token separately and never logs the raw token' do
      allow(Rails.logger).to receive(:warn).and_call_original
      auth = { 'Authorization' => "Bearer #{token}" }

      2.times { get '/api/v1/raids', headers: auth }
      get '/api/v1/raids', headers: auth
      expect(response).to have_http_status(:too_many_requests)

      other = Doorkeeper::AccessToken.create!(resource_owner_id: create(:user).id, expires_in: 30.days,
                                              scopes: 'public').token
      get '/api/v1/raids', headers: { 'Authorization' => "Bearer #{other}" }
      expect(response).to have_http_status(:ok)

      expect(Rails.logger).to have_received(:warn).with(%r{rule=token/minute key=token:[0-9a-f]{32} })
      expect(Rails.logger).not_to have_received(:warn).with(/#{token}/)
    end

    it 'never limits the healthcheck' do
      5.times { get '/api/v1/version', headers: { 'Authorization' => "Bearer #{token}" } }
      expect(response).to have_http_status(:ok)
    end
  end
end
