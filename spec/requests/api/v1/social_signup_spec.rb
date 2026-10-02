# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Social signup and the password banner', :social_auth, type: :request do
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:identity) do
    SocialAuth::Identity.new(provider: 'discord', uid: 'discord-9', email: 'new@example.com', is_private_email: false)
  end
  let(:ticket) { SocialAuth::Ticket.issue(identity, purpose: :signup) }

  def signup(body)
    post '/api/v1/users', params: body.to_json, headers: headers
  end

  describe 'POST /api/v1/users with a signup ticket' do
    it 'creates a passwordless user with the identity and returns the token body' do
      expect { signup(signup_ticket: ticket, user: { username: 'newplayer' }) }
        .to change(User, :count).by(1).and change(UserIdentity, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      user = User.find_by(username: 'newplayer')
      expect(body).to include('token_type' => 'Bearer', 'access_token' => be_present, 'refresh_token' => be_present)
      expect(body['user']).to eq('id' => user.id, 'username' => 'newplayer', 'role' => user.role)
      expect(user).to have_attributes(email: 'new@example.com', email_verified: true)
      expect(user).not_to be_password
      expect(user.user_identities.first).to have_attributes(provider: 'discord', provider_uid: 'discord-9',
                                                            email: 'new@example.com', email_verified: true)
    end

    it 'does not send a verification email for a verified email' do
      expect { signup(signup_ticket: ticket, user: { username: 'newplayer' }) }
        .not_to have_enqueued_job(SendEmailVerificationJob)
    end

    it "uses the ticket's verified email over one in the request" do
      signup(signup_ticket: ticket, user: { username: 'newplayer', email: 'other@example.com' })
      expect(User.find_by(username: 'newplayer').email).to eq('new@example.com')
    end

    context 'when the provider did not verify an email' do
      before { identity.email = nil }

      it 'uses the email from the request and sends a verification email' do
        expect { signup(signup_ticket: ticket, user: { username: 'newplayer', email: 'Typed@Example.com' }) }
          .to have_enqueued_job(SendEmailVerificationJob)

        expect(response).to have_http_status(:created)
        user = User.find_by(username: 'newplayer')
        expect(user).to have_attributes(email: 'typed@example.com', email_verified: false)
        expect(user.user_identities.first.email).to be_nil
      end

      it 'requires an email' do
        expect { signup(signup_ticket: ticket, user: { username: 'newplayer' }) }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Validation failed')
        expect(response.parsed_body['messages']).to include(a_string_matching(/Email/))
      end
    end

    it 'keeps an Apple name as the display name' do
      apple = SocialAuth::Identity.new(provider: 'apple', uid: 'apple-1', email: 'x@privaterelay.appleid.com',
                                       is_private_email: true, name: 'Lyria Skydweller')
      signup(signup_ticket: SocialAuth::Ticket.issue(apple, purpose: :signup), user: { username: 'lyria' })

      user = User.find_by(username: 'lyria')
      expect(user.display_name).to eq('Lyria Skydweller')
      expect(user.user_identities.first.is_private_email).to be true
    end

    it 'drops a name that is not a valid display name instead of failing' do
      apple = SocialAuth::Identity.new(provider: 'apple', uid: 'apple-2', email: 'y@example.com',
                                       is_private_email: false, name: 'A' * 40)
      signup(signup_ticket: SocialAuth::Ticket.issue(apple, purpose: :signup), user: { username: 'longname' })

      expect(response).to have_http_status(:created)
      expect(User.find_by(username: 'longname').display_name).to be_nil
    end

    it 'returns the same validation errors as a password signup' do
      create(:user, username: 'taken')
      signup(signup_ticket: ticket, user: { username: 'taken' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to include('error' => 'Validation failed',
                                              'messages' => include('Username has already been taken'))
    end

    it 'refuses a link ticket' do
      signup(signup_ticket: SocialAuth::Ticket.issue(identity, purpose: :link), user: { username: 'newplayer' })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_ticket')
    end

    it 'refuses an expired ticket' do
      ticket
      travel 11.minutes
      signup(signup_ticket: ticket, user: { username: 'newplayer' })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_ticket')
    end

    it 'refuses a tampered ticket' do
      signup(signup_ticket: ticket.sub('--', '-x-'), user: { username: 'newplayer' })

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_ticket')
    end

    it 'refuses a ticket whose identity is already linked' do
      signup(signup_ticket: ticket, user: { username: 'newplayer' })
      expect { signup(signup_ticket: ticket, user: { username: 'secondtry', email: 'b@example.com' }) }
        .not_to change(User, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'invalid_ticket')
    end

    it 'limits ticket signups per client IP' do
      20.times { signup(signup_ticket: 'bogus', user: { username: 'x' }) }
      expect(response).to have_http_status(:unauthorized)

      signup(signup_ticket: 'bogus', user: { username: 'x' })
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'POST /api/v1/users with a password' do
    it 'is unchanged: returns the token view and sends a verification email' do
      expect do
        signup(user: { email: 'pw@example.com', password: 'password123', password_confirmation: 'password123',
                       username: 'pwuser' })
      end.to have_enqueued_job(SendEmailVerificationJob)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to include('token', 'username', 'email_verified')
      expect(response.parsed_body).not_to have_key('refresh_token')
      expect(User.find_by(username: 'pwuser')).to be_password
    end

    it 'still requires a password' do
      signup(user: { email: 'pw@example.com', username: 'pwuser' })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['messages']).to include("Password can't be blank")
    end
  end

  describe 'the password banner' do
    let(:user) do
      User.new(username: 'nopassword', email: 'nopassword@example.com').tap do |u|
        u.user_identities.build(provider: 'discord', provider_uid: 'd')
        u.save!
      end
    end
    let(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '') }
    let(:auth_headers) { headers.merge('Authorization' => "Bearer #{token.token}") }

    it 'shows in the settings view for a passwordless account' do
      get '/api/v1/users/me', headers: auth_headers

      expect(response.parsed_body).to include('has_password' => false, 'password_prompt_dismissed' => false)
      expect(response.parsed_body.keys).not_to include('password_digest', 'password_prompt_dismissed_at')
    end

    it 'reports a password for password accounts' do
      password_user = create(:user)
      password_token = Doorkeeper::AccessToken.create!(resource_owner_id: password_user.id, expires_in: 30.days, scopes: '')
      get '/api/v1/users/me', headers: { 'Authorization' => "Bearer #{password_token.token}" }

      expect(response.parsed_body['has_password']).to be true
    end

    it 'stays dismissed once dismissed' do
      put '/api/v1/users/me', params: { user: { password_prompt_dismissed: true } }.to_json, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).not_to have_key('password_prompt_dismissed')
      dismissed_at = user.reload.password_prompt_dismissed_at
      expect(dismissed_at).to be_present

      put '/api/v1/users/me', params: { user: { password_prompt_dismissed: false } }.to_json, headers: auth_headers
      expect(user.reload.password_prompt_dismissed_at).to eq(dismissed_at)

      get '/api/v1/users/me', headers: auth_headers
      expect(response.parsed_body['password_prompt_dismissed']).to be true
    end

    it 'does not accept the timestamp directly' do
      put '/api/v1/users/me', params: { user: { password_prompt_dismissed_at: 1.year.from_now } }.to_json,
                              headers: auth_headers
      expect(user.reload.password_prompt_dismissed_at).to be_nil
    end

    it 'lets a passwordless account update other settings' do
      put '/api/v1/users/me', params: { user: { language: 'ja' } }.to_json, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.language).to eq('ja')
    end

    it "does not let a passwordless account log in with an empty password" do
      post '/oauth/token', params: { grant_type: 'password', email: user.email, password: '' }
      expect(response).to have_http_status(:bad_request).or have_http_status(:unauthorized)
      expect(response.parsed_body).not_to have_key('access_token')
    end

    it 'lets a password reset set a first password' do
      raw = user.generate_reset_token!
      put '/api/v1/password_resets', params: { email: user.email, token: raw, password: 'firstpass1',
                                               password_confirmation: 'firstpass1' }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate('firstpass1')).to eq(user)
    end
  end
end
