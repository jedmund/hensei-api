# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Events', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:user) { create(:user, role: 1) }
  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 7200, scopes: '')
  end
  let(:user_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 7200, scopes: '')
  end
  let(:editor_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{editor_token.token}" }
  end
  let(:user_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token.token}" }
  end

  describe 'GET /api/v1/events' do
    let!(:event1) { create(:event, name: 'Unite and Fight 2026') }
    let!(:event2) { create(:event, name: 'Rise of the Beasts', event_type: :rise_of_the_beasts) }

    it 'returns all events' do
      get '/api/v1/events'

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.length).to eq(2)
    end

    it 'filters by event type' do
      get '/api/v1/events', params: { by_type: 'rise_of_the_beasts' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json.first['name']).to eq('Rise of the Beasts')
    end

    it 'does not require authentication' do
      get '/api/v1/events'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/events' do
    let(:valid_params) do
      {
        event: {
          name: 'New Event',
          slug: 'new-event',
          event_type: 'unite_and_fight',
          start_time: 1.day.from_now.iso8601,
          end_time: 3.days.from_now.iso8601
        }
      }
    end

    it 'creates an event when user has editor role' do
      post '/api/v1/events', params: valid_params.to_json, headers: editor_headers

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['name']).to eq('New Event')
      expect(json['slug']).to eq('new-event')
      expect(json['banner_image']).to eq('images/events/new-event.png')
      expect(Event.count).to eq(1)
    end

    it 'returns 401 for non-editor users' do
      post '/api/v1/events', params: valid_params.to_json, headers: user_headers

      expect(response).to have_http_status(:unauthorized)
      expect(Event.count).to eq(0)
    end

    it 'returns 401 without authentication' do
      post '/api/v1/events',
           params: valid_params.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns validation errors for invalid params' do
      post '/api/v1/events',
           params: { event: { name: '' } }.to_json,
           headers: editor_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/events/:id' do
    let!(:event) { create(:event, start_time: 1.hour.ago, end_time: 1.hour.from_now) }

    it 'returns the event' do
      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['name']).to eq(event.name)
    end

    it 'returns 404 for non-existent event' do
      get '/api/v1/events/999999'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT /api/v1/events/:id' do
    let!(:event) { create(:event) }

    it 'updates an event when user has editor role' do
      put "/api/v1/events/#{event.id}",
          params: { event: { name: 'Updated Name' } }.to_json,
          headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(event.reload.name).to eq('Updated Name')
    end

    it 'returns 401 for non-editor users' do
      put "/api/v1/events/#{event.id}",
          params: { event: { name: 'Updated Name' } }.to_json,
          headers: user_headers

      expect(response).to have_http_status(:unauthorized)
      expect(event.reload.name).not_to eq('Updated Name')
    end

    it 'returns 401 without authentication' do
      put "/api/v1/events/#{event.id}",
          params: { event: { name: 'Updated Name' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
