# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Social sign-in', :social_auth, type: :request do
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:identity) do
    SocialAuth::Identity.new(provider: 'discord', uid: 'discord-1', email: 'player@example.com',
                             is_private_email: false, username_hint: 'player.one')
  end

  before { allow(SocialAuth).to receive(:verify).and_return(identity) }

  def sign_in(provider = 'discord', **body)
    post "/api/v1/auth/#{provider}", params: { assertion: 'provider-proof' }.merge(body).to_json, headers: headers
  end

  describe 'a known identity' do
    let(:user) { create(:user) }

    before { user.user_identities.create!(provider: 'discord', provider_uid: 'discord-1') }

    it 'returns the same token body as /oauth/token' do
      sign_in

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include('token_type' => 'Bearer', 'expires_in' => 1.month.to_i)
      expect(body['access_token']).to be_present
      expect(body['refresh_token']).to be_present
      expect(body['created_at']).to be_a(Integer)
      expect(body['user']).to eq('id' => user.id, 'username' => user.username, 'role' => user.role,
                                 'deletion_scheduled_at' => nil)
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'matches the keys of a password login' do
      post '/oauth/token', params: { grant_type: 'password', email: user.email, password: 'password' }
      password_keys = response.parsed_body.keys

      sign_in
      expect(response.parsed_body.keys).to match_array(password_keys)
    end

    it 'issues a working access token and refresh token' do
      sign_in
      body = response.parsed_body

      get '/api/v1/users/me', headers: { 'Authorization' => "Bearer #{body['access_token']}" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(user.id)

      post '/oauth/token', params: { grant_type: 'refresh_token', refresh_token: body['refresh_token'] }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['access_token']).to be_present
    end

    it 'records when the identity was used' do
      sign_in
      expect(user.user_identities.first.last_used_at).to be_within(5.seconds).of(Time.current)
    end

    it 'passes the assertion, nonce and name to the verifier' do
      sign_in('discord', nonce: 'n-1', name: 'Gran')
      expect(SocialAuth).to have_received(:verify)
        .with('discord', assertion: 'provider-proof', nonce: 'n-1', name: 'Gran')
    end
  end

  describe 'a new identity with an unknown email' do
    it 'returns a signup ticket with a suggested username' do
      expect { sign_in }.not_to change(User, :count)

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body).to include('status' => 'signup_required', 'suggested_username' => 'playerone', 'email_required' => false)
      ticket = SocialAuth::Ticket.read(body['ticket'], purpose: :signup)
      expect(ticket).to include('provider' => 'discord', 'provider_uid' => 'discord-1',
                                'email' => 'player@example.com', 'email_verified' => true)
    end

    it 'asks for an email when the provider did not verify one' do
      identity.email = nil
      sign_in

      expect(response.parsed_body).to include('status' => 'signup_required', 'email_required' => true)
    end
  end

  describe 'a new identity whose verified email belongs to a user' do
    let!(:existing) { create(:user, email: 'player@example.com') }

    it 'returns a link ticket and does not link automatically' do
      sign_in

      body = response.parsed_body
      expect(body).to include('status' => 'link_required', 'provider' => 'discord')
      expect(body).not_to have_key('access_token')
      expect(SocialAuth::Ticket.read(body['ticket'], purpose: :link))
        .to include('provider_uid' => 'discord-1', 'user_id' => existing.id)
      expect(SocialAuth::Ticket.read(body['ticket'], purpose: :signup)).to be_nil
      expect(existing.user_identities).to be_empty
    end

    it 'ignores the email when the provider did not verify it' do
      identity.email = nil
      sign_in

      expect(response.parsed_body).to include('status' => 'signup_required', 'email_required' => true)
    end
  end

  it 'returns invalid_assertion when verification fails' do
    allow(SocialAuth).to receive(:verify).and_raise(SocialAuth::Error)
    sign_in

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq('error' => 'invalid_assertion')
  end

  it 'returns invalid_assertion without an assertion' do
    allow(SocialAuth).to receive(:verify).and_call_original
    post '/api/v1/auth/discord', params: {}.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq('error' => 'invalid_assertion')
  end

  it 'returns 404 for a provider that is not enabled' do
    with_env('APPLE_SERVICES_ID' => nil) { sign_in('apple') }

    expect(response).to have_http_status(:not_found)
    expect(SocialAuth).not_to have_received(:verify)
  end

  it 'returns 404 for an unknown provider' do
    sign_in('myspace')
    expect(response).to have_http_status(:not_found)
  end

  describe 'rate limits' do
    it 'limits attempts per provider account' do
      SocialAuthentication::PROVIDER_UID_LIMIT.times { sign_in }
      expect(response).to have_http_status(:ok)

      sign_in
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'limits attempts per client IP' do
      allow(SocialAuth).to receive(:verify).and_raise(SocialAuth::Error)
      30.times { sign_in }
      expect(response).to have_http_status(:unauthorized)

      sign_in
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
