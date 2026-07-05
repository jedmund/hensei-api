# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calculator panel validation endpoint', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  it 'reports per-panel results (references without parties fail, not crash)' do
    post '/api/v1/calculator/validate_panels', headers: headers
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['ok']).to be(false) # golden parties don't exist in the test DB
    expect(body['panels']).to all(include('party', 'ok', 'mismatches'))
  end

  it 'rejects non-editors' do
    post '/api/v1/calculator/validate_panels'
    expect(response).to have_http_status(:unauthorized)
  end
end
