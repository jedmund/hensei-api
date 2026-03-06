require 'rails_helper'

RSpec.describe 'Api::V1::GwEvents', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: 9) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:admin_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: admin.id, expires_in: 30.days, scopes: 'public')
  end
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token.token}" } }
  let(:admin_headers) { { 'Authorization' => "Bearer #{admin_token.token}" } }

  describe 'GET /api/v1/gw_events' do
    let!(:upcoming_event) { create(:gw_event, :upcoming) }
    let!(:active_event) { create(:gw_event, :active) }
    let!(:finished_event) { create(:gw_event, :finished) }

    it 'returns all events' do
      get '/api/v1/gw_events'
      expect(response).to have_http_status(:ok)
      expect(json_response['gw_events'].length).to eq(3)
    end
  end

  describe 'GET /api/v1/gw_events/:id' do
    let!(:event) { create(:gw_event) }

    it 'returns the event' do
      get "/api/v1/gw_events/#{event.id}"
      expect(response).to have_http_status(:ok)
      expect(json_response['gw_event']['id']).to eq(event.id)
      expect(json_response['gw_event']['element']).to eq(GwEvent.elements[event.element])
    end

    it 'returns 404 for non-existent event' do
      get '/api/v1/gw_events/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/gw_events' do
    let(:valid_params) do
      {
        gw_event: {
          element: 'Fire',
          start_date: 1.week.from_now.to_date,
          end_date: 2.weeks.from_now.to_date,
          event_number: 50
        }
      }
    end

    context 'as admin' do
      it 'creates a new event' do
        expect {
          post '/api/v1/gw_events', params: valid_params, headers: admin_headers
        }.to change(GwEvent, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['gw_event']['element']).to eq(GwEvent.elements['Fire'])
        expect(json_response['gw_event']['event_number']).to eq(50)
      end

      it 'returns errors for invalid params' do
        expect {
          post '/api/v1/gw_events', params: { gw_event: { element: '' } }, headers: admin_headers
        }.not_to change(GwEvent, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular user' do
      it 'returns unauthorized' do
        post '/api/v1/gw_events', params: valid_params, headers: auth_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/gw_events', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/gw_events/:id' do
    let!(:event) { create(:gw_event) }
    let(:update_params) { { gw_event: { event_number: 99 } } }

    context 'as admin' do
      it 'updates the event' do
        put "/api/v1/gw_events/#{event.id}", params: update_params, headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json_response['gw_event']['event_number']).to eq(99)
      end
    end

    context 'as regular user' do
      it 'returns unauthorized' do
        put "/api/v1/gw_events/#{event.id}", params: update_params, headers: auth_headers
        expect(response).to have_http_status(:unauthorized)
        expect(event.reload.event_number).not_to eq(99)
      end
    end
  end

  private

  def json_response
    response.parsed_body
  end
end
