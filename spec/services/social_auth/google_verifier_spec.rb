# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialAuth::GoogleVerifier, :social_auth do
  let(:client_id) { SocialAuthHelpers::CLIENT_IDS['GOOGLE_CLIENT_ID'] }
  let(:jwks_url) { described_class::JWKS_URL }
  let(:nonce) { 'nonce-123' }
  let(:claims) do
    {
      'iss' => 'https://accounts.google.com',
      'aud' => client_id,
      'sub' => '1234567890',
      'exp' => 10.minutes.from_now.to_i,
      'iat' => Time.current.to_i,
      'nonce' => nonce,
      'email' => 'Someone@Example.com',
      'email_verified' => true,
      'given_name' => 'Someone'
    }
  end

  before { stub_provider_get(jwks_url, body: jwks_for([rsa_key, 'key-1'])) }

  def verify(token, nonce: self.nonce)
    SocialAuth.verify('google', assertion: token, nonce: nonce)
  end

  it 'returns the identity for a valid ID token' do
    identity = verify(sign_id_token(claims))

    expect(identity).to have_attributes(provider: 'google', uid: '1234567890', email: 'someone@example.com',
                                        is_private_email: false, username_hint: 'someone')
    expect(identity).to be_email_verified
  end

  it 'accepts the issuer without a scheme' do
    expect(verify(sign_id_token(claims.merge('iss' => 'accounts.google.com'))).uid).to eq('1234567890')
  end

  it 'drops an unverified email' do
    identity = verify(sign_id_token(claims.merge('email_verified' => false)))

    expect(identity.email).to be_nil
    expect(identity).not_to be_email_verified
  end

  it 'caches the JWKS' do
    verify(sign_id_token(claims))
    verify(sign_id_token(claims))

    expect(HTTParty).to have_received(:get).with(jwks_url, anything).once
  end

  {
    'a wrong audience' => { 'aud' => 'someone-elses-client' },
    'a wrong issuer' => { 'iss' => 'https://evil.example.com' },
    'an expired token' => { 'exp' => 1.minute.ago.to_i },
    'a different nonce' => { 'nonce' => 'other-nonce' },
    'a missing nonce claim' => { 'nonce' => nil },
    'a missing subject' => { 'sub' => nil }
  }.each do |description, overrides|
    it "rejects #{description}" do
      token = sign_id_token(claims.merge(overrides).compact)
      expect { verify(token) }.to raise_error(SocialAuth::Error)
    end
  end

  it 'rejects a request without a nonce' do
    expect { verify(sign_id_token(claims), nonce: nil) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects a token signed by another key' do
    token = sign_id_token(claims, key: rsa_key(:attacker))
    expect { verify(token) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects an HMAC token signed with the public key' do
    token = JWT.encode(claims, rsa_key.public_key.to_pem, 'HS256', kid: 'key-1')
    expect { verify(token) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects an unsigned token' do
    token = JWT.encode(claims, nil, 'none')
    expect { verify(token) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects garbage' do
    expect { verify('not-a-jwt') }.to raise_error(SocialAuth::Error)
  end

  it 'raises the generic error when the JWKS cannot be fetched' do
    stub_provider_get(jwks_url, body: 'oops', code: 500)
    expect { verify(sign_id_token(claims)) }.to raise_error(SocialAuth::Error)
  end

  it 'raises the generic error when the provider times out' do
    allow(HTTParty).to receive(:get).and_raise(Net::ReadTimeout)
    expect { verify(sign_id_token(claims)) }.to raise_error(SocialAuth::Error)
  end

  it 'raises the generic error when the provider is not enabled' do
    with_env('GOOGLE_CLIENT_ID' => nil) do
      expect { verify(sign_id_token(claims)) }.to raise_error(SocialAuth::Error)
    end
  end

  describe 'key rotation' do
    it 'refetches the JWKS when the token uses an unknown key' do
      verify(sign_id_token(claims))
      stub_provider_get(jwks_url, body: jwks_for([rsa_key, 'key-1'], [rsa_key(:rotated), 'key-2']))

      identity = verify(sign_id_token(claims, key: rsa_key(:rotated), kid: 'key-2'))

      expect(identity.uid).to eq('1234567890')
    end

    it 'refetches at most once a minute for unknown keys' do
      verify(sign_id_token(claims))
      2.times do
        token = sign_id_token(claims, key: rsa_key(:attacker), kid: "made-up-#{SecureRandom.hex(4)}")
        expect { verify(token) }.to raise_error(SocialAuth::Error)
      end

      # The initial fetch plus one refetch.
      expect(HTTParty).to have_received(:get).with(jwks_url, anything).twice
    end
  end
end
