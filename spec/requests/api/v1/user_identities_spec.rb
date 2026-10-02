# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User identities', :social_auth, type: :request do
  let(:user) { create(:user) }
  let(:access_token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '') }
  let(:headers) { { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' } }
  let(:identity) do
    SocialAuth::Identity.new(provider: 'google', uid: 'google-1', email: 'me@example.com', is_private_email: false)
  end

  describe 'GET /api/v1/users/me/identities' do
    it "lists the user's linked providers" do
      user.user_identities.create!(provider: 'apple', provider_uid: 'a', email: 'x@privaterelay.appleid.com',
                                   email_verified: true, is_private_email: true)
      create(:user).user_identities.create!(provider: 'discord', provider_uid: 'someone-else')

      get '/api/v1/users/me/identities', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        a_hash_including('provider' => 'apple', 'email' => 'x@privaterelay.appleid.com', 'is_private_email' => true,
                         'created_at' => be_present)
      )
      expect(response.parsed_body.first.keys).to contain_exactly('provider', 'email', 'is_private_email', 'created_at')
    end

    it 'requires authentication' do
      get '/api/v1/users/me/identities'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/users/me/identities' do
    def link(body)
      post '/api/v1/users/me/identities', params: body.to_json, headers: headers
    end

    context 'with a provider assertion (settings)' do
      before { allow(SocialAuth).to receive(:verify).and_return(identity) }

      it 'links the provider' do
        link(provider: 'google', assertion: 'id-token', nonce: 'n')

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include('provider' => 'google', 'email' => 'me@example.com', 'is_private_email' => false)
        expect(user.user_identities.pluck(:provider_uid)).to eq(['google-1'])
        expect(SocialAuth).to have_received(:verify).with('google', assertion: 'id-token', nonce: 'n', name: nil)
      end

      it "refuses an identity linked to someone else's account" do
        other = create(:user)
        other.user_identities.create!(provider: 'google', provider_uid: 'google-1')

        link(provider: 'google', assertion: 'id-token', nonce: 'n')

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to eq('error' => 'identity_taken')
        expect(user.user_identities).to be_empty
        expect(other.user_identities.count).to eq(1)
      end

      it 'refuses a second account from the same provider' do
        user.user_identities.create!(provider: 'google', provider_uid: 'google-0')

        link(provider: 'google', assertion: 'id-token', nonce: 'n')

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to eq('error' => 'provider_already_linked')
      end

      it 'returns invalid_assertion when verification fails' do
        allow(SocialAuth).to receive(:verify).and_raise(SocialAuth::Error)
        link(provider: 'google', assertion: 'bad', nonce: 'n')

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_assertion')
      end

      it 'returns invalid_assertion for a provider that is not enabled' do
        with_env('GOOGLE_CLIENT_ID' => nil) { link(provider: 'google', assertion: 'id-token', nonce: 'n') }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_assertion')
        expect(SocialAuth).not_to have_received(:verify)
      end

      it 'limits attempts per provider account' do
        SocialAuthentication::PROVIDER_UID_LIMIT.times { link(provider: 'google', assertion: 'id-token', nonce: 'n') }
        link(provider: 'google', assertion: 'id-token', nonce: 'n')

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context 'with a link ticket' do
      let(:ticket) { SocialAuth::Ticket.issue(identity, purpose: :link, user_id: user.id) }

      # The user logs in with their password after the ticket was issued.
      def fresh_login
        ticket
        travel 1.second
        access_token
      end

      it 'links the provider for a session that logged in after the ticket was issued' do
        fresh_login
        link(link_ticket: ticket)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include('provider' => 'google', 'email' => 'me@example.com')
        expect(user.user_identities.first).to have_attributes(provider_uid: 'google-1', email_verified: true)
      end

      it 'links the provider when the matched user presents the ticket' do
        fresh_login
        link(link_ticket: ticket)

        expect(response).to have_http_status(:created)
        expect(user.user_identities.count).to eq(1)
      end

      it 'refuses the ticket from a different logged-in user' do
        other = create(:user)
        ticket
        travel 1.second
        other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other.id, expires_in: 30.days, scopes: '')

        post '/api/v1/users/me/identities', params: { link_ticket: ticket }.to_json,
                                            headers: headers.merge('Authorization' => "Bearer #{other_token.token}")

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_ticket')
        expect(UserIdentity.count).to eq(0)
      end

      it 'refuses a session that logged in before the ticket was issued' do
        access_token
        travel 1.second
        link(link_ticket: ticket)

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_ticket')
        expect(user.user_identities).to be_empty
      end

      it 'refuses an expired ticket' do
        fresh_login
        travel 11.minutes
        link(link_ticket: ticket)

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_ticket')
      end

      it 'refuses a signup ticket' do
        signup_ticket = SocialAuth::Ticket.issue(identity, purpose: :signup)
        user
        travel 1.second
        access_token
        link(link_ticket: signup_ticket)

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_ticket')
      end

      it 'refuses a tampered ticket' do
        fresh_login
        link(link_ticket: "#{ticket}x")

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to eq('error' => 'invalid_ticket')
      end

      it "refuses an identity linked to someone else's account" do
        create(:user).user_identities.create!(provider: 'google', provider_uid: 'google-1')
        fresh_login
        link(link_ticket: ticket)

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to eq('error' => 'identity_taken')
      end
    end

    it 'requires authentication' do
      post '/api/v1/users/me/identities', params: { provider: 'google', assertion: 'x' }.to_json,
                                          headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/users/me/identities/:provider' do
    it 'unlinks a provider from an account with a password' do
      user.user_identities.create!(provider: 'discord', provider_uid: 'd')

      delete '/api/v1/users/me/identities/discord', headers: headers

      expect(response).to have_http_status(:no_content)
      expect(user.user_identities.reload).to be_empty
    end

    it 'returns 404 when the provider is not linked' do
      delete '/api/v1/users/me/identities/discord', headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not unlink someone else's identity" do
      other = create(:user)
      other.user_identities.create!(provider: 'discord', provider_uid: 'd')

      delete '/api/v1/users/me/identities/discord', headers: headers

      expect(response).to have_http_status(:not_found)
      expect(other.user_identities.count).to eq(1)
    end

    context 'without a password' do
      let(:user) do
        User.new(username: 'nopassword', email: 'nopassword@example.com').tap do |u|
          u.user_identities.build(provider: 'discord', provider_uid: 'd')
          u.save!
        end
      end

      it "refuses to remove the account's last way to log in" do
        delete '/api/v1/users/me/identities/discord', headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq('error' => 'last_login_method')
        expect(user.user_identities.count).to eq(1)
      end

      it 'unlinks one provider while another remains' do
        user.user_identities.create!(provider: 'google', provider_uid: 'g')

        delete '/api/v1/users/me/identities/discord', headers: headers

        expect(response).to have_http_status(:no_content)
        expect(user.user_identities.pluck(:provider)).to eq(['google'])
      end
    end
  end
end
