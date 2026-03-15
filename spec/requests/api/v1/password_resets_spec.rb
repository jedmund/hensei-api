# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password Resets API', type: :request do
  let(:headers) { { 'Content-Type' => 'application/json' } }

  describe 'POST /api/v1/password_resets' do
    let(:user) { create(:user, email: 'reset@example.com') }

    it 'enqueues a reset email for an existing user' do
      expect {
        post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers
      }.to have_enqueued_job(SendPasswordResetEmailJob)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 for a non-existent email without enqueuing' do
      expect {
        post '/api/v1/password_resets', params: { email: 'nobody@example.com' }.to_json, headers: headers
      }.not_to have_enqueued_job(SendPasswordResetEmailJob)
      expect(response).to have_http_status(:ok)
    end

    it 'returns the same response body for existing and non-existent emails' do
      post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers
      existing_body = response.parsed_body

      post '/api/v1/password_resets', params: { email: 'nobody@example.com' }.to_json, headers: headers
      missing_body = response.parsed_body

      expect(existing_body).to eq(missing_body)
    end

    it 'does not enqueue a second email during the cooldown period' do
      post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers

      expect {
        post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers
      }.not_to have_enqueued_job(SendPasswordResetEmailJob)
    end

    it 'enqueues again after the cooldown period' do
      post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers

      travel_to(3.minutes.from_now) do
        expect {
          post '/api/v1/password_resets', params: { email: user.email }.to_json, headers: headers
        }.to have_enqueued_job(SendPasswordResetEmailJob)
      end
    end

    it 'handles mixed-case email addresses' do
      expect {
        post '/api/v1/password_resets', params: { email: 'RESET@Example.COM' }.to_json, headers: headers
      }.to have_enqueued_job(SendPasswordResetEmailJob)
    end
  end

  describe 'PUT /api/v1/password_resets' do
    let(:user) { create(:user, email: 'reset@example.com', password: 'oldpassword', password_confirmation: 'oldpassword') }
    let!(:raw_token) { user.generate_reset_token! }

    it 'changes the password with a valid token' do
      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'newpassword', password_confirmation: 'newpassword'
      }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate('newpassword')).to be_truthy
      expect(user.authenticate('oldpassword')).to be false
    end

    it 'revokes all existing access tokens' do
      token = Doorkeeper::AccessToken.create!(
        resource_owner_id: user.id, expires_in: 30.days, scopes: 'public'
      )

      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'newpassword', password_confirmation: 'newpassword'
      }.to_json, headers: headers

      expect(Doorkeeper::AccessToken.find_by(id: token.id)).to be_nil
    end

    it 'prevents reuse of the same token' do
      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'newpassword', password_confirmation: 'newpassword'
      }.to_json, headers: headers
      expect(response).to have_http_status(:ok)

      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'anotherpassword', password_confirmation: 'anotherpassword'
      }.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects an expired token' do
      travel_to(61.minutes.from_now) do
        put '/api/v1/password_resets', params: {
          email: user.email, token: raw_token,
          password: 'newpassword', password_confirmation: 'newpassword'
        }.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'rejects a wrong token' do
      put '/api/v1/password_resets', params: {
        email: user.email, token: 'wrong',
        password: 'newpassword', password_confirmation: 'newpassword'
      }.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects a non-existent email' do
      put '/api/v1/password_resets', params: {
        email: 'nobody@example.com', token: raw_token,
        password: 'newpassword', password_confirmation: 'newpassword'
      }.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'rejects a password that is too short' do
      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'short', password_confirmation: 'short'
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects mismatched password confirmation' do
      put '/api/v1/password_resets', params: {
        email: user.email, token: raw_token,
        password: 'newpassword', password_confirmation: 'different'
      }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
