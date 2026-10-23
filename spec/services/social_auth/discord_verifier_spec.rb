# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocialAuth::DiscordVerifier, :social_auth do
  let(:client_id) { SocialAuthHelpers::CLIENT_IDS['DISCORD_CLIENT_ID'] }
  let(:user) do
    { 'id' => '80351110224678912', 'username' => 'nelly.dev', 'email' => 'Nelly@Example.com', 'verified' => true }
  end
  let(:authorization) do
    { 'application' => { 'id' => client_id }, 'scopes' => %w[identify email], 'user' => user.slice('id', 'username') }
  end

  before do
    stub_provider_get(described_class::AUTHORIZATION_URL, body: authorization)
    stub_provider_get(described_class::USER_URL, body: user)
  end

  def verify
    SocialAuth.verify('discord', assertion: 'discord-access-token')
  end

  it 'returns the identity for a token issued to our application' do
    identity = verify

    expect(identity).to have_attributes(provider: 'discord', uid: '80351110224678912',
                                        email: 'nelly@example.com', username_hint: 'nelly.dev')
  end

  it 'sends the token as a bearer token' do
    verify

    expect(HTTParty).to have_received(:get)
      .with(described_class::AUTHORIZATION_URL, hash_including(headers: { 'Authorization' => 'Bearer discord-access-token' }))
  end

  it 'rejects a token issued to another Discord application' do
    stub_provider_get(described_class::AUTHORIZATION_URL,
                      body: authorization.merge('application' => { 'id' => '999' }))

    expect { verify }.to raise_error(SocialAuth::Error)
    expect(HTTParty).not_to have_received(:get).with(described_class::USER_URL, anything)
  end

  it 'rejects a token without an application' do
    stub_provider_get(described_class::AUTHORIZATION_URL, body: authorization.except('application'))
    expect { verify }.to raise_error(SocialAuth::Error)
  end

  it 'rejects a token Discord does not accept' do
    stub_provider_get(described_class::AUTHORIZATION_URL, body: { 'message' => '401: Unauthorized' }, code: 401)
    expect { verify }.to raise_error(SocialAuth::Error)
  end

  it 'rejects mismatched users' do
    stub_provider_get(described_class::USER_URL, body: user.merge('id' => '1'))
    expect { verify }.to raise_error(SocialAuth::Error)
  end

  it 'drops an unverified email' do
    stub_provider_get(described_class::USER_URL, body: user.merge('verified' => false))

    identity = verify
    expect(identity.email).to be_nil
    expect(identity).not_to be_email_verified
  end

  it 'handles a user without an email' do
    stub_provider_get(described_class::USER_URL, body: user.except('email'))
    expect(verify.email).to be_nil
  end

  it 'rejects a non-JSON response' do
    stub_provider_get(described_class::USER_URL, body: '<html>')
    expect { verify }.to raise_error(SocialAuth::Error)
  end
end
