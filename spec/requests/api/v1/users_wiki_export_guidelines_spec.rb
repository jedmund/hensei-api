# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Wiki export guidelines acceptance', type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  it 'starts unaccepted in the settings view' do
    get '/api/v1/users/me', headers: auth_headers

    expect(response.parsed_body).to include('wiki_export_guidelines_accepted' => false)
    expect(response.parsed_body.keys).not_to include('wiki_export_guidelines_accepted_at')
  end

  it 'stays accepted once accepted' do
    put '/api/v1/users/me', params: { user: { wiki_export_guidelines_accepted: true } }.to_json, headers: auth_headers
    expect(response).to have_http_status(:ok)
    accepted_at = user.reload.wiki_export_guidelines_accepted_at
    expect(accepted_at).to be_present

    put '/api/v1/users/me', params: { user: { wiki_export_guidelines_accepted: false } }.to_json, headers: auth_headers
    put '/api/v1/users/me', params: { user: { wiki_export_guidelines_accepted: true } }.to_json, headers: auth_headers
    expect(user.reload.wiki_export_guidelines_accepted_at).to eq(accepted_at)

    get '/api/v1/users/me', headers: auth_headers
    expect(response.parsed_body['wiki_export_guidelines_accepted']).to be true
  end

  it 'does not accept the timestamp directly' do
    put '/api/v1/users/me', params: { user: { wiki_export_guidelines_accepted_at: 1.year.from_now } }.to_json,
                            headers: auth_headers
    expect(user.reload.wiki_export_guidelines_accepted_at).to be_nil
  end

  it 'leaves the password prompt alone' do
    put '/api/v1/users/me', params: { user: { wiki_export_guidelines_accepted: true } }.to_json, headers: auth_headers
    expect(user.reload.password_prompt_dismissed_at).to be_nil
  end

  it "does not accept for someone else's account" do
    other = create(:user)
    put "/api/v1/users/#{other.id}", params: { user: { wiki_export_guidelines_accepted: true } }.to_json,
                                     headers: auth_headers

    expect(response).to have_http_status(:forbidden)
    expect(other.reload.wiki_export_guidelines_accepted_at).to be_nil
  end
end
