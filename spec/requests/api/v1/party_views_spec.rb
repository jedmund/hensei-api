# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PartyViews', :party_views, type: :request do
  let(:secret) { 'internal-s3cret' }
  let(:owner) { create(:user) }
  let(:viewer) { create(:user) }
  let(:party) { create(:party, user: owner, visibility: 1) }
  let(:internal) { { 'X-Internal-Secret' => secret, 'X-Client-IP' => '198.51.100.7' } }
  let(:today) { PartyViews::Recorder.date_for(Time.current) }

  around do |example|
    original = ENV.fetch('API_INTERNAL_SECRET', nil)
    ENV['API_INTERNAL_SECRET'] = secret
    example.run
  ensure
    original.nil? ? ENV.delete('API_INTERNAL_SECRET') : ENV['API_INTERNAL_SECRET'] = original
  end

  def view(target = party, headers: internal)
    post "/api/v1/parties/#{target.id}/view", headers: headers
  end

  def counts
    PartyViews::Recorder.counts(today)
  end

  it 'counts a signed-out viewer once a day' do
    2.times { view }

    expect(response).to have_http_status(:no_content)
    expect(counts).to eq(party.id => 1)
  end

  it 'counts different signed-out viewers separately without storing their IPs' do
    view
    view(headers: internal.merge('X-Client-IP' => '203.0.113.9'))

    expect(counts).to eq(party.id => 2)
    members = Sidekiq.redis { |r| r.call('SMEMBERS', "#{PartyViewsRedis::PREFIX}:seen:#{today.iso8601}:#{party.id}") }
    expect(members.join).not_to include('198.51.100.7', '203.0.113.9')
  end

  it 'identifies a signed-in viewer by account, not IP' do
    headers = internal.merge(bearer_headers(viewer))
    view(headers: headers)
    view(headers: headers.merge('X-Client-IP' => '203.0.113.9'))
    view

    expect(counts).to eq(party.id => 2)
  end

  it "doesn't count the owner" do
    view(headers: internal.merge(bearer_headers(owner)))

    expect(response).to have_http_status(:no_content)
    expect(counts).to be_empty
  end

  it "doesn't count private or unlisted teams" do
    view(create(:party, visibility: 3))
    view(create(:party, visibility: 2))

    expect(response).to have_http_status(:no_content)
    expect(counts).to be_empty
  end

  it "doesn't count a signed-out viewer without a public client IP" do
    view(headers: { 'X-Internal-Secret' => secret, 'X-Client-IP' => '10.0.0.1' })
    view(headers: { 'X-Internal-Secret' => secret })

    expect(counts).to be_empty
  end

  it 'answers 204 for an unknown party' do
    post "/api/v1/parties/#{SecureRandom.uuid}/view", headers: internal

    expect(response).to have_http_status(:no_content)
  end

  describe 'calls not from the web server' do
    it 'rejects a call without the internal secret' do
      view(headers: { 'X-Client-IP' => '198.51.100.7' })

      expect(response).to have_http_status(:forbidden)
      expect(counts).to be_empty
    end

    it 'rejects a forged internal secret, even with a session' do
      view(headers: internal.merge('X-Internal-Secret' => 'forged-s3cret').merge(bearer_headers(viewer)))

      expect(response).to have_http_status(:forbidden)
      expect(counts).to be_empty
    end

    it 'rejects every call when no internal secret is configured' do
      ENV.delete('API_INTERNAL_SECRET')
      view(headers: internal.merge('X-Internal-Secret' => ''))

      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'rate limits one visitor' do
    121.times { view }

    expect(response).to have_http_status(:too_many_requests)
  end

  it "doesn't expose view counts in the party response" do
    view
    get "/api/v1/parties/#{party.shortcode}"

    expect(response.body).not_to include('"views"', 'view_count')
  end
end
