# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account deletion', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, password: 'correct-horse', password_confirmation: 'correct-horse') }
  let(:access_token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '') }
  let(:headers) { { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' } }

  describe 'POST /api/v1/users/me/deletion' do
    def request_deletion(password)
      post '/api/v1/users/me/deletion', params: { password: password }.to_json, headers: headers
    end

    it 'schedules the deletion 30 days out and signs the user out everywhere' do
      other_session = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: '')
      someone_else = Doorkeeper::AccessToken.create!(resource_owner_id: create(:user).id, expires_in: 30.days,
                                                     scopes: '')

      freeze_time do
        expect { request_deletion('correct-horse') }
          .to have_enqueued_job(SendAccountDeletionEmailJob).with(user.id, 'scheduled')

        expect(response).to have_http_status(:ok)
        expect(user.reload.deletion_scheduled_at).to eq(30.days.from_now)
        expect(Time.zone.parse(response.parsed_body['deletion_scheduled_at'])).to eq(30.days.from_now)
      end
      expect(Doorkeeper::AccessToken.where(id: [access_token.id, other_session.id])).to be_empty
      expect(Doorkeeper::AccessToken.exists?(someone_else.id)).to be(true)
    end

    it 'keeps the original date when asked twice' do
      user.update_columns(deletion_scheduled_at: 10.days.from_now)
      original = user.reload.deletion_scheduled_at

      expect { request_deletion('correct-horse') }.not_to have_enqueued_job(SendAccountDeletionEmailJob)

      expect(user.reload.deletion_scheduled_at).to eq(original)
    end

    it 'refuses the wrong password' do
      request_deletion('wrong')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq('error' => 'invalid_password')
      expect(user.reload.deletion_scheduled_at).to be_nil
      expect(Doorkeeper::AccessToken.exists?(access_token.id)).to be(true)
    end

    it 'asks an account without a password to set one first' do
      user.update_columns(password_digest: nil)

      request_deletion('')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq('error' => 'password_required')
      expect(user.reload.deletion_scheduled_at).to be_nil
    end

    it 'only ever schedules the signed-in user' do
      other = create(:user)

      post '/api/v1/users/me/deletion', params: { password: 'correct-horse', user_id: other.id }.to_json,
                                        headers: headers

      expect(user.reload.deletion_scheduled_at).to be_present
      expect(other.reload.deletion_scheduled_at).to be_nil
    end

    it 'requires authentication' do
      post '/api/v1/users/me/deletion', params: { password: 'correct-horse' }.to_json,
                                        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/users/me/deletion' do
    it 'cancels a scheduled deletion' do
      user.update_columns(deletion_scheduled_at: 10.days.from_now)

      expect { delete '/api/v1/users/me/deletion', headers: headers }
        .to have_enqueued_job(SendAccountDeletionEmailJob).with(user.id, 'cancelled')

      expect(response).to have_http_status(:no_content)
      expect(user.reload.deletion_scheduled_at).to be_nil
    end

    it "doesn't email when nothing was scheduled" do
      expect { delete '/api/v1/users/me/deletion', headers: headers }.not_to have_enqueued_job

      expect(response).to have_http_status(:no_content)
    end

    it "can't cancel someone else's deletion" do
      other = create(:user, deletion_scheduled_at: 10.days.from_now)

      delete '/api/v1/users/me/deletion', params: { user_id: other.id }.to_json, headers: headers

      expect(other.reload.deletion_scheduled_at).to be_present
    end
  end

  describe 'login while scheduled' do
    it 'includes the deletion date with the token' do
      user.update_columns(deletion_scheduled_at: 10.days.from_now)

      post '/oauth/token', params: { grant_type: 'password', email: user.email, password: 'correct-horse' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('user', 'deletion_scheduled_at')).to be_present
    end
  end
end
