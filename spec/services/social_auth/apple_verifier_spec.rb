# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialAuth::AppleVerifier, :social_auth do
  let(:services_id) { SocialAuthHelpers::CLIENT_IDS['APPLE_SERVICES_ID'] }
  let(:nonce) { 'apple-nonce' }
  let(:claims) do
    {
      'iss' => 'https://appleid.apple.com',
      'aud' => services_id,
      'sub' => '001234.abcdef.1234',
      'exp' => 10.minutes.from_now.to_i,
      'iat' => Time.current.to_i,
      'nonce' => nonce,
      'email' => 'abc123@privaterelay.appleid.com',
      'email_verified' => 'true',
      'is_private_email' => 'true'
    }
  end

  before { stub_provider_get(described_class::JWKS_URL, body: jwks_for([rsa_key, 'apple-key'])) }

  def verify(token, name: nil)
    SocialAuth.verify('apple', assertion: token, nonce: nonce, name: name)
  end

  def token(overrides = {})
    sign_id_token(claims.merge(overrides).compact, kid: 'apple-key')
  end

  it 'returns the identity, normalizing string booleans' do
    identity = verify(token)

    expect(identity).to have_attributes(provider: 'apple', uid: '001234.abcdef.1234',
                                        email: 'abc123@privaterelay.appleid.com', is_private_email: true)
    expect(identity).to be_email_verified
  end

  it 'does not suggest a username from a private relay address' do
    expect(verify(token).username_hint).to be_nil
  end

  it 'accepts boolean claims too' do
    identity = verify(token('email_verified' => true, 'is_private_email' => false, 'email' => 'me@example.com'))

    expect(identity).to have_attributes(email: 'me@example.com', is_private_email: false, username_hint: 'me')
  end

  it 'drops an email Apple says is unverified' do
    expect(verify(token('email_verified' => 'false')).email).to be_nil
  end

  it "keeps the name from Apple's first sign-in" do
    identity = verify(token, name: { 'firstName' => 'Lyria', 'lastName' => 'Skydweller' })

    expect(identity.name).to eq('Lyria Skydweller')
    expect(identity.username_hint).to eq('Lyria Skydweller')
  end

  it 'accepts the name as a string' do
    expect(verify(token, name: '  Katalina  ').name).to eq('Katalina')
  end

  it "rejects a token for another app's audience" do
    expect { verify(token('aud' => 'com.example.other')) }.to raise_error(SocialAuth::Error)
  end

  it "rejects Google's issuer" do
    expect { verify(token('iss' => 'https://accounts.google.com')) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects a token with the wrong nonce' do
    expect { verify(token('nonce' => 'replayed')) }.to raise_error(SocialAuth::Error)
  end

  it 'rejects an expired token' do
    expect { verify(token('exp' => 1.hour.ago.to_i)) }.to raise_error(SocialAuth::Error)
  end
end
