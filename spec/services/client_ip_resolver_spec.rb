# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClientIpResolver do
  let(:edge_ip) { '84.17.44.227' }

  def resolve(headers = {}, env: {})
    rack_env = Rack::MockRequest.env_for('/api/v1/search', 'REMOTE_ADDR' => edge_ip)
    headers.each { |name, value| rack_env["HTTP_#{name.upcase.tr('-', '_')}"] = value }
    with_env(env) { described_class.call(ActionDispatch::Request.new(rack_env)) }
  end

  def with_env(vars)
    original = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  it 'falls back to remote_ip without forwarding headers' do
    expect(resolve).to eq(edge_ip)
  end

  describe 'CF-Connecting-IP' do
    it 'is trusted when no origin secret is configured' do
      expect(resolve({ 'CF-Connecting-IP' => '203.0.113.9' })).to eq('203.0.113.9')
    end

    it 'ignores private and invalid values' do
      expect(resolve({ 'CF-Connecting-IP' => '10.0.0.5' })).to eq(edge_ip)
      expect(resolve({ 'CF-Connecting-IP' => '100.64.1.1' })).to eq(edge_ip)
      expect(resolve({ 'CF-Connecting-IP' => 'not-an-ip' })).to eq(edge_ip)
    end

    it 'requires a matching X-Origin-Auth when an origin secret is configured' do
      env = { 'CLOUDFLARE_ORIGIN_SECRET' => 'current', 'CLOUDFLARE_ORIGIN_SECRET_PREVIOUS' => 'previous' }

      expect(resolve({ 'CF-Connecting-IP' => '203.0.113.9' }, env: env)).to eq(edge_ip)
      expect(resolve({ 'CF-Connecting-IP' => '203.0.113.9', 'X-Origin-Auth' => 'wrong' }, env: env)).to eq(edge_ip)
      expect(resolve({ 'CF-Connecting-IP' => '203.0.113.9', 'X-Origin-Auth' => 'current' }, env: env))
        .to eq('203.0.113.9')
      expect(resolve({ 'CF-Connecting-IP' => '203.0.113.9', 'X-Origin-Auth' => 'previous' }, env: env))
        .to eq('203.0.113.9')
    end
  end

  describe 'X-Client-IP from the web app' do
    let(:env) { { 'API_INTERNAL_SECRET' => 's3cret' } }

    it 'is used with a valid internal secret' do
      headers = { 'X-Internal-Secret' => 's3cret', 'X-Client-IP' => '198.51.100.7', 'CF-Connecting-IP' => '203.0.113.9' }
      expect(resolve(headers, env: env)).to eq('198.51.100.7')
    end

    it 'is ignored with a wrong or missing secret' do
      expect(resolve({ 'X-Internal-Secret' => 'nope', 'X-Client-IP' => '198.51.100.7' }, env: env)).to eq(edge_ip)
      expect(resolve({ 'X-Client-IP' => '198.51.100.7' }, env: env)).to eq(edge_ip)
    end

    it 'is ignored when no internal secret is configured' do
      expect(resolve({ 'X-Internal-Secret' => '', 'X-Client-IP' => '198.51.100.7' })).to eq(edge_ip)
    end
  end
end
