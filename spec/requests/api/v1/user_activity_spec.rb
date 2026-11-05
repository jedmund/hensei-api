# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Recording when a user was last seen', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  it 'stamps last_seen_at on a signed-in request, without touching updated_at' do
    updated_at = user.updated_at
    get '/api/v1/users/me', headers: headers

    expect(user.reload.last_seen_at).to be_within(5.seconds).of(Time.current)
    expect(user.updated_at).to eq(updated_at)
  end

  it 'writes at most every five minutes' do
    seen = 2.minutes.ago.change(usec: 0)
    user.update_columns(last_seen_at: seen)
    get '/api/v1/users/me', headers: headers
    expect(user.reload.last_seen_at).to eq(seen)

    user.update_columns(last_seen_at: 6.minutes.ago)
    get '/api/v1/users/me', headers: headers
    expect(user.reload.last_seen_at).to be_within(5.seconds).of(Time.current)
  end

  it 'records nothing for anonymous requests' do
    get "/api/v1/users/#{user.username}"
    expect(user.reload.last_seen_at).to be_nil
  end

  it 'still records the extension version, hourly unless it changes' do
    get '/api/v1/users/me', headers: headers.merge('X-Extension-Version' => '2.0.0')
    stamped = user.reload.last_extension_version_at
    expect(user.last_extension_version).to eq('2.0.0')

    get '/api/v1/users/me', headers: headers.merge('X-Extension-Version' => '2.0.0')
    expect(user.reload.last_extension_version_at).to eq(stamped)

    get '/api/v1/users/me', headers: headers.merge('X-Extension-Version' => '2.1.0')
    expect(user.reload.last_extension_version).to eq('2.1.0')
  end
end
