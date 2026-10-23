# frozen_string_literal: true

# Helpers for social login specs: locally generated RSA keys, JWKS fixtures,
# signed ID tokens, stubbed provider HTTP, and the provider client ID variables.
module SocialAuthHelpers
  CLIENT_IDS = {
    'DISCORD_CLIENT_ID' => 'discord-client-id',
    'GOOGLE_CLIENT_ID' => 'google-client-id.apps.googleusercontent.com',
    'APPLE_SERVICES_ID' => 'team.granblue.signin'
  }.freeze

  # Generating RSA keys is slow, so specs share a few.
  def self.rsa_key(name)
    @rsa_keys ||= {}
    @rsa_keys[name] ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def rsa_key(name = :primary)
    SocialAuthHelpers.rsa_key(name)
  end

  def jwks_for(*pairs)
    { keys: pairs.map { |key, kid| JWT::JWK.new(key.public_key, kid: kid, use: 'sig', alg: 'RS256').export } }
  end

  def sign_id_token(claims, key: rsa_key, kid: 'key-1', algorithm: 'RS256')
    JWT.encode(claims, key, algorithm, kid: kid)
  end

  # Stubs HTTParty.get for one URL. body may be a Hash (sent as JSON) or a String.
  def stub_provider_get(url, body:, code: 200)
    response = instance_double(HTTParty::Response, code: code, body: body.is_a?(String) ? body : body.to_json)
    allow(HTTParty).to receive(:get).with(url, anything).and_return(response)
    response
  end

  def with_env(vars)
    original = vars.keys.index_with { |key| ENV.fetch(key, nil) }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include SocialAuthHelpers

  config.before do
    Rails.application.config.x.social_auth_cache.clear
  end

  # Enables every provider for specs tagged :social_auth.
  config.around(:each, :social_auth) do |example|
    with_env(SocialAuthHelpers::CLIENT_IDS) { example.run }
  end
end
