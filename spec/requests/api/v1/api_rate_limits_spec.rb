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
end
