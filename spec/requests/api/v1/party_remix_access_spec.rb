# frozen_string_literal: true

require 'rails_helper'

# Who may remix a party (POST /parties/:shortcode/remix): anyone who can view
# it. Private parties 404 for everyone else; anonymous ones also open with
# their edit key.
RSpec.describe 'POST /api/v1/parties/:id/remix access', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  def remix(target, request_headers = headers)
    post "/api/v1/parties/#{target.shortcode}/remix", params: {}.to_json, headers: request_headers
  end

  it "remixes someone else's public party into the user's account" do
    source = create(:party, user: create(:user), name: 'Theirs', visibility: 1)

    expect { remix(source) }.to change(Party, :count).by(1)

    expect(response).to have_http_status(:created)
    json = response.parsed_body['party']
    expect(json['user']['id']).to eq(user.id)
    expect(json['source_party']['id']).to eq(source.id)
    remixed = Party.find(json['id'])
    expect(remixed.name).to eq('Remix of Theirs')
    expect(remixed.remix).to be(true)
  end

  it "hides someone else's private party" do
    source = create(:party, user: create(:user), visibility: 3)

    expect { remix(source) }.not_to change(Party, :count)

    expect(response).to have_http_status(:not_found)
  end

  it 'remixes a private anonymous party with its edit key' do
    source = create(:party, user: nil, visibility: 3)
    source.update_columns(edit_key: 'anon-key')

    remix(source, { 'X-Edit-Key' => 'anon-key', 'Content-Type' => 'application/json' })

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['party']['user']).to be_nil
  end

  it 'hides a private anonymous party with the wrong edit key' do
    source = create(:party, user: nil, visibility: 3)
    source.update_columns(edit_key: 'anon-key')

    remix(source, { 'X-Edit-Key' => 'wrong', 'Content-Type' => 'application/json' })

    expect(response).to have_http_status(:not_found)
  end

  it 'remixes a public party for a signed-out visitor' do
    source = create(:party, user: create(:user), visibility: 1)

    remix(source, { 'Content-Type' => 'application/json' })

    expect(response).to have_http_status(:created)
    expect(Party.find(response.parsed_body['party']['id']).user_id).to be_nil
  end

  it 'returns not found for an unknown shortcode' do
    post '/api/v1/parties/NOPE99/remix', params: {}.to_json, headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
