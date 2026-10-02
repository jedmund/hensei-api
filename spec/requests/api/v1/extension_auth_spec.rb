# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Extension auth', type: :request do
  let(:user) { create(:user) }
  let(:session_token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '') }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }
  let(:verifier) { SecureRandom.urlsafe_base64(32) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

  def create_code(body = { code_challenge: challenge, code_challenge_method: 'S256' }, token: session_token)
    headers = json_headers.merge(token ? { 'Authorization' => "Bearer #{token.token}" } : {})
    post '/api/v1/extension_auth/codes', params: body.to_json, headers: headers
  end

  def exchange(code, code_verifier = verifier)
    post '/api/v1/extension_auth/token', params: { code: code, code_verifier: code_verifier }.to_json,
                                         headers: json_headers
  end

  def issued_code(for_user = user, code_challenge: challenge)
    ExtensionAuthCode.issue(for_user, code_challenge: code_challenge)
  end

  describe 'POST /api/v1/extension_auth/codes' do
    it 'creates a one-time code for the logged-in user' do
      create_code

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body.keys).to contain_exactly('code', 'expires_in')
      expect(body['expires_in']).to eq(60)
      expect(body['code']).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(response.headers['Cache-Control']).to include('no-store')

      record = ExtensionAuthCode.sole
      expect(record.user).to eq(user)
      expect(record.code_challenge).to eq(challenge)
      expect(record.code_digest).to eq(Digest::SHA256.hexdigest(body['code']))
    end

    it 'requires a valid token' do
      create_code(token: nil)
      expect(response).to have_http_status(:unauthorized)

      session_token.revoke
      create_code
      expect(response).to have_http_status(:unauthorized)

      expect(ExtensionAuthCode.count).to eq(0)
    end

    it 'rejects an expired token' do
      expired = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 1, scopes: '')
      travel(2.seconds) { create_code(token: expired) }
      expect(response).to have_http_status(:unauthorized)
    end

    [
      ['a missing challenge', { code_challenge_method: 'S256' }],
      ['a missing method', { code_challenge: 'x' * 43 }],
      ['the plain method', { code_challenge: 'x' * 43, code_challenge_method: 'plain' }],
      ['a short challenge', { code_challenge: 'x' * 42, code_challenge_method: 'S256' }],
      ['a padded challenge', { code_challenge: "#{'x' * 43}=", code_challenge_method: 'S256' }],
      ['a non-base64url challenge', { code_challenge: "#{'x' * 42}+", code_challenge_method: 'S256' }],
      ['a non-string challenge', { code_challenge: ['x' * 43], code_challenge_method: 'S256' }]
    ].each do |description, body|
      it "rejects #{description}" do
        create_code(body)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq('error' => 'invalid_request')
        expect(ExtensionAuthCode.count).to eq(0)
      end
    end

    it 'limits code creation per user' do
      10.times { create_code }
      expect(response).to have_http_status(:created)

      create_code
      expect(response).to have_http_status(:too_many_requests)

      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: create(:user).id, expires_in: 30.days, scopes: '')
      create_code(token: other_token)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'POST /api/v1/extension_auth/token' do
    it 'returns a new token pair, separate from the session that created the code' do
      create_code
      exchange(response.parsed_body['code'])

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include('token_type' => 'Bearer', 'expires_in' => 1.month.to_i)
      expect(body['created_at']).to be_a(Integer)
      expect(body['user']).to eq('id' => user.id, 'username' => user.username, 'role' => user.role)
      expect(body['access_token']).to be_present
      expect(body['refresh_token']).to be_present
      expect(body['access_token']).not_to eq(session_token.token)
      expect(body['refresh_token']).not_to eq(session_token.refresh_token)
      expect(response.headers['Cache-Control']).to include('no-store')

      issued = Doorkeeper::AccessToken.find_by(token: body['access_token'])
      expect(issued.id).not_to eq(session_token.id)
      expect(issued.resource_owner_id).to eq(user.id)
      expect(session_token.reload).to be_accessible
    end

    it 'matches the keys of a password login' do
      post '/oauth/token', params: { grant_type: 'password', email: user.email, password: 'password' }
      password_keys = response.parsed_body.keys

      exchange(issued_code)
      expect(response.parsed_body.keys).to match_array(password_keys)
    end

    it 'issues a working access token and refresh token' do
      exchange(issued_code)
      body = response.parsed_body

      get '/api/v1/users/me', headers: { 'Authorization' => "Bearer #{body['access_token']}" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(user.id)

      post '/oauth/token', params: { grant_type: 'refresh_token', refresh_token: body['refresh_token'] }
      expect(response).to have_http_status(:ok)
    end

    it "only ever yields tokens for the code's creator" do
      other = create(:user)
      other_verifier = SecureRandom.urlsafe_base64(32)
      other_code = issued_code(other, code_challenge: ExtensionAuthCode.challenge_for(other_verifier))
      code = issued_code

      exchange(other_code, other_verifier)
      expect(response.parsed_body['user']['id']).to eq(other.id)
      expect(Doorkeeper::AccessToken.find_by(token: response.parsed_body['access_token']).resource_owner_id).to eq(other.id)

      exchange(code)
      expect(response.parsed_body['user']['id']).to eq(user.id)
      expect(Doorkeeper::AccessToken.find_by(token: response.parsed_body['access_token']).resource_owner_id).to eq(user.id)
    end

    describe 'failures' do
      shared_examples 'invalid_grant' do
        it 'returns invalid_grant and issues no tokens' do
          expect { attempt }.not_to change(Doorkeeper::AccessToken, :count)
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq('error' => 'invalid_grant')
        end
      end

      context 'with an unknown code' do
        let(:attempt) { exchange(SecureRandom.urlsafe_base64(32)) }

        it_behaves_like 'invalid_grant'
      end

      context 'with an expired code' do
        let!(:code) { issued_code }
        let(:attempt) { travel(61.seconds) { exchange(code) } }

        it_behaves_like 'invalid_grant'
      end

      context 'with an already-used code' do
        let!(:code) { issued_code.tap { |c| exchange(c) } }
        let(:attempt) { exchange(code) }

        it_behaves_like 'invalid_grant'
      end

      context 'with a wrong verifier' do
        let!(:code) { issued_code }
        let(:attempt) { exchange(code, SecureRandom.urlsafe_base64(32)) }

        it_behaves_like 'invalid_grant'

        it 'uses the code up' do
          attempt
          exchange(code)
          expect(response.parsed_body).to eq('error' => 'invalid_grant')
        end
      end

      context 'with a missing code' do
        let(:attempt) { exchange(nil) }

        it_behaves_like 'invalid_grant'
      end

      context 'with a missing verifier' do
        let!(:code) { issued_code }
        let(:attempt) { exchange(code, nil) }

        it_behaves_like 'invalid_grant'
      end
    end

    it 'lets only one of two concurrent redemptions through' do
      code = issued_code
      # Simulates the race: both requests look the code up before either
      # claims it, so only the conditional update decides the winner.
      loaded = ExtensionAuthCode.find_by(code_digest: ExtensionAuthCode.digest(code))
      allow(ExtensionAuthCode).to receive(:find_by).and_return(loaded, ExtensionAuthCode.find(loaded.id))

      exchange(code)
      first_status = response.status
      exchange(code)
      second = response

      expect([first_status, second.status]).to contain_exactly(200, 400)
      expect(second.parsed_body).to eq('error' => 'invalid_grant')
      expect(Doorkeeper::AccessToken.where(resource_owner_id: user.id).count).to eq(1)
    end

    it 'limits exchanges per client IP' do
      20.times { exchange(SecureRandom.urlsafe_base64(32)) }
      expect(response).to have_http_status(:bad_request)

      exchange(issued_code)
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it 'keeps the code and verifier out of the logs' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter('code' => 'c', 'code_verifier' => 'v', 'code_challenge' => 'x')

    expect(filtered).to eq('code' => '[FILTERED]', 'code_verifier' => '[FILTERED]', 'code_challenge' => 'x')
  end
end
