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

    it 'leaves out other kinds of event and unapproved Guild Wars' do
      create(:event)
      create(:gw_event, status: :draft)

      get '/api/v1/gw_events'
      expect(json_response['gw_events'].pluck('id')).to contain_exactly(upcoming_event.id, active_event.id,
                                                                        finished_event.id)
    end

    it 'keeps the Guild War shape, with dates as JST days' do
      get '/api/v1/gw_events'
      event = json_response['gw_events'].find { |e| e['id'] == active_event.id }
      expect(event.keys).to contain_exactly('id', 'start_date', 'end_date', 'event_number', 'element', 'status')
      expect(event).to include('start_date' => 2.days.ago.to_date.iso8601,
                               'end_date' => 5.days.from_now.to_date.iso8601, 'status' => 'active')
    end
  end

  describe 'GET /api/v1/gw_events/status' do
    it 'returns the next Guild War and the one running now' do
      upcoming = create(:gw_event, :upcoming)
      active = create(:gw_event, :active)

      get '/api/v1/gw_events/status'
      expect(json_response['upcoming']['id']).to eq(upcoming.id)
      expect(json_response['recent']['id']).to eq(active.id)
    end

    it 'falls back to one that ended in the last week' do
      ended = create(:gw_event, start_date: 10.days.ago.to_date, end_date: 3.days.ago.to_date)
      create(:gw_event, :finished)

      get '/api/v1/gw_events/status'
      expect(json_response['upcoming']).to be_nil
      expect(json_response['recent']['id']).to eq(ended.id)
    end
  end

  describe 'GET /api/v1/gw_events/:id' do
    let!(:event) { create(:gw_event) }

    it 'returns the event' do
      get "/api/v1/gw_events/#{event.id}"
      expect(response).to have_http_status(:ok)
      expect(json_response['gw_event']['id']).to eq(event.id)
      expect(json_response['gw_event']['element']).to eq(Event.elements[event.element])
    end

    it 'returns 404 for an event that is not a Guild War' do
      get "/api/v1/gw_events/#{create(:event).id}"
      expect(response).to have_http_status(:not_found)
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
        }.to change(Event.unite_and_fight, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['gw_event']['element']).to eq(Event.elements['Fire'])
        expect(json_response['gw_event']['event_number']).to eq(50)
      end

      it 'stores an approved event from 19:00 JST on Day 1 to 23:59:59 JST on the last day' do
        post '/api/v1/gw_events', params: valid_params, headers: admin_headers

        event = Event.find(json_response['gw_event']['id'])
        jst = Time.find_zone('Asia/Tokyo')
        expect(event).to have_attributes(kind: 'unite_and_fight', status: 'approved', series: 'unite_and_fight',
                                         name_en: 'Unite and Fight #50', element: 'Fire')
        expect(event.starts_at).to eq(jst.local(*1.week.from_now.to_date.then { |d| [d.year, d.month, d.day] }, 19))
        expect(event.ends_at).to eq(jst.local(*2.weeks.from_now.to_date.then { |d| [d.year, d.month, d.day] }, 23, 59, 59))
        expect(json_response['gw_event']).to include('start_date' => 1.week.from_now.to_date.iso8601,
                                                     'end_date' => 2.weeks.from_now.to_date.iso8601)
      end

      it 'requires an event number' do
        expect {
          post '/api/v1/gw_events', params: { gw_event: valid_params[:gw_event].except(:event_number) },
                                    headers: admin_headers
        }.not_to change(Event, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects a malformed date' do
        post '/api/v1/gw_events', params: { gw_event: valid_params[:gw_event].merge(start_date: 'soon') },
                                  headers: admin_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'clears the cached Home feed' do
        allow(HomeFeed).to receive(:expire)
        post '/api/v1/gw_events', params: valid_params, headers: admin_headers
        expect(HomeFeed).to have_received(:expire)
      end

      it 'returns errors for invalid params' do
        expect {
          post '/api/v1/gw_events', params: { gw_event: { element: '' } }, headers: admin_headers
        }.not_to change(Event.unite_and_fight, :count)
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
        expect(event.reload.name_en).to eq('Unite and Fight #99')
      end

      it 'moves the dates' do
        day = 3.weeks.from_now.to_date
        put "/api/v1/gw_events/#{event.id}", params: { gw_event: { end_date: day.iso8601 } },
                                             headers: admin_headers
        expect(json_response['gw_event']['end_date']).to eq(day.iso8601)
        expect(event.reload.ends_at).to eq(Time.find_zone('Asia/Tokyo').local(day.year, day.month, day.day, 23, 59, 59))
      end

      it 'does not touch other kinds of event' do
        other = create(:event)
        put "/api/v1/gw_events/#{other.id}", params: update_params, headers: admin_headers
        expect(response).to have_http_status(:not_found)
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
