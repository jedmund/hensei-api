# frozen_string_literal: true

require 'rails_helper'

# Rack::Attack is disabled in the test env by default (so throttling can't
# interfere with the rest of the suite); this spec enables it around its
# examples and clears the counter store between them.
RSpec.describe 'Rack::Attack', type: :request do
  let(:user) { create(:user) }
  let(:token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public').token
  end

  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  describe 'bot-path blocklist' do
    it 'answers 404 for scanner probes before they reach the app' do
      get '/wp-login.php'
      expect(response).to have_http_status(:not_found)
    end

    it 'blocks any path ending in .php' do
      get '/api/v1/whatever/x.php'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'per-token throttle' do
    it 'returns 429 once a token exceeds its limit, scoped to that token' do
      original = ENV.fetch('RACK_ATTACK_TOKEN_LIMIT', nil)
      ENV['RACK_ATTACK_TOKEN_LIMIT'] = '2'
      headers = { 'Authorization' => "Bearer #{token}" }

      2.times do
        get '/api/v1/users/me', headers: headers
        expect(response).to have_http_status(:ok)
      end

      get '/api/v1/users/me', headers: headers
      expect(response).to have_http_status(:too_many_requests)

      # A different token is unaffected.
      other = Doorkeeper::AccessToken.create!(resource_owner_id: create(:user).id, expires_in: 30.days,
                                              scopes: 'public').token
      get '/api/v1/users/me', headers: { 'Authorization' => "Bearer #{other}" }
      expect(response).to have_http_status(:ok)
    ensure
      ENV['RACK_ATTACK_TOKEN_LIMIT'] = original
    end
  end
end
