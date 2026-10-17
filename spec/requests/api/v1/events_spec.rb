# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Events', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:member) { create(:user, role: 1) }
  let(:editor_headers) { bearer_headers(editor) }
  let(:member_headers) { bearer_headers(member) }

  def json_response
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/events' do
    let!(:current) { create(:event, :current, name_en: 'Current') }
    let!(:upcoming) { create(:event, :upcoming, :unite_and_fight, name_en: 'GW', event_number: 80) }
    let!(:past) { create(:event, :past, name_en: 'Past') }
    let!(:draft) { create(:event, :current, :draft, name_en: 'Draft') }
    let!(:raid) { create(:raid) }

    before { create(:event_raid, event: current, raid: raid) }

    it 'returns approved events only' do
      get '/api/v1/events'
      expect(response).to have_http_status(:ok)
      expect(json_response['events'].map { |e| e['name']['en'] }).to contain_exactly('Current', 'GW', 'Past')
    end

    it 'filters by scope and kind' do
      get '/api/v1/events', params: { scope: 'current' }
      expect(json_response['events'].map { |e| e['id'] }).to eq([current.id])

      get '/api/v1/events', params: { scope: 'upcoming' }
      expect(json_response['events'].map { |e| e['id'] }).to eq([upcoming.id])

      get '/api/v1/events', params: { scope: 'past' }
      expect(json_response['events'].map { |e| e['id'] }).to eq([past.id])

      get '/api/v1/events', params: { kind: 'unite_and_fight' }
      expect(json_response['events'].map { |e| e['id'] }).to eq([upcoming.id])
    end

    it 'renders the event shape with linked raids and integer elements' do
      get '/api/v1/events', params: { scope: 'current' }
      event = json_response['events'].first
      expect(event).to include('kind' => 'story_event', 'status' => 'approved', 'element' => nil,
                               'advantage_element' => nil, 'image_url' => nil)
      expect(event['raids'].map { |r| r['id'] }).to eq([raid.id])
      expect(event).not_to have_key('source_refs')
      expect(event).not_to have_key('event_number')

      get '/api/v1/events', params: { kind: 'unite_and_fight' }
      gw = json_response['events'].first
      expect(gw['element']).to eq(3) # Water boss
      expect(gw['advantage_element']).to eq(4) # Earth teams
    end

    it 'lets editors filter by status and see editor fields' do
      get '/api/v1/events', params: { status: 'draft' }, headers: editor_headers
      expect(json_response['events'].map { |e| e['id'] }).to eq([draft.id])
      expect(json_response['events'].first).to include('source_refs' => {}, 'source_payload' => {})

      get '/api/v1/events', params: { status: 'all' }, headers: editor_headers
      expect(json_response['events'].size).to eq(4)
    end

    it 'ignores status for non-editors' do
      get '/api/v1/events', params: { status: 'all' }, headers: member_headers
      expect(json_response['events'].size).to eq(3)
    end
  end

  describe 'GET /api/v1/events/:id' do
    it 'returns an approved event publicly' do
      event = create(:event)
      get "/api/v1/events/#{event.id}"
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(event.id)
    end

    it 'returns 404 for a draft to non-editors and the event to editors' do
      event = create(:event, :draft)
      get "/api/v1/events/#{event.id}", headers: member_headers
      expect(response).to have_http_status(:not_found)

      get "/api/v1/events/#{event.id}", headers: editor_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/events' do
    let(:raids) { create_list(:raid, 2) }
    let(:params) do
      { event: { name_en: 'Unite and Fight', name_jp: '古戦場', kind: 'unite_and_fight', element: 'fire',
                 starts_at: 3.days.from_now.iso8601, ends_at: 10.days.from_now.iso8601,
                 raid_ids: [raids.second.id, raids.first.id] } }
    end

    it 'creates a draft event with ordered raids' do
      post '/api/v1/events', params: params, headers: editor_headers

      expect(response).to have_http_status(:created)
      expect(json_response).to include('status' => 'draft', 'kind' => 'unite_and_fight', 'element' => 2)
      expect(json_response['raids'].map { |r| r['id'] }).to eq([raids.second.id, raids.first.id])
    end

    it 'accepts event_number for Unite and Fight' do
      post '/api/v1/events', params: params.deep_merge(event: { event_number: 81 }), headers: editor_headers
      expect(response).to have_http_status(:created)
      expect(json_response['event_number']).to eq(81)
    end

    it 'accepts the element as an integer' do
      post '/api/v1/events', params: params.deep_merge(event: { element: 3 }), headers: editor_headers
      expect(json_response['element']).to eq(3)
    end

    it 'requires an element for Unite and Fight' do
      post '/api/v1/events', params: params.deep_merge(event: { element: '' }), headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an unknown raid with 422 and creates nothing' do
      bad = params.deep_merge(event: { raid_ids: ['00000000-0000-0000-0000-000000000000'] })
      expect { post '/api/v1/events', params: bad, headers: editor_headers }.not_to change(Event, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('raid_ids')
    end

    it 'rejects an end before the start' do
      post '/api/v1/events', params: params.deep_merge(event: { ends_at: 1.day.ago.iso8601 }), headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-editors' do
      post '/api/v1/events', params: params, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/events/:id' do
    let(:event) { create(:event, :draft) }
    let(:raid) { create(:raid) }

    before { create(:event_raid, event: event, raid: raid) }

    it 'keeps raid links when raid_ids is omitted' do
      put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed' } }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(json_response['name']['en']).to eq('Renamed')
      expect(json_response['raids'].map { |r| r['id'] }).to eq([raid.id])
    end

    it 'replaces raid links when raid_ids is given' do
      other = create(:raid)
      put "/api/v1/events/#{event.id}", params: { event: { raid_ids: [other.id] } }, headers: editor_headers
      expect(json_response['raids'].map { |r| r['id'] }).to eq([other.id])
    end

    it 'returns 422 (not 404) for an unknown raid' do
      put "/api/v1/events/#{event.id}", params: { event: { raid_ids: ['nope'] } }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(event.reload.event_raids.map(&:raid_id)).to eq([raid.id])
    end

    it 'returns 401 for non-editors' do
      put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed' } }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'approve and hide' do
    let(:event) { create(:event, :draft) }

    it 'approves and hides as an editor' do
      post "/api/v1/events/#{event.id}/approve", headers: editor_headers
      expect(json_response['status']).to eq('approved')

      post "/api/v1/events/#{event.id}/hide", headers: editor_headers
      expect(json_response['status']).to eq('hidden')
    end

    it 'returns 401 for non-editors' do
      post "/api/v1/events/#{event.id}/approve", headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(event.reload).to be_draft
    end
  end

  describe 'POST /api/v1/events/:id/upload_image' do
    let(:event) { create(:event) }

    before do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:delete)
    end

    it 'stores a banner under events/<id>' do
      upload = Rack::Test::UploadedFile.new(StringIO.new(jpeg_bytes), 'image/jpeg', original_filename: 'b.jpg')
      post "/api/v1/events/#{event.id}/upload_image", params: { image: upload }, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(IconStorage).to have_received(:put).with("events/#{event.id}.jpg", kind_of(String), content_type: 'image/jpeg')
      expect(json_response['image_url']).to start_with("events/#{event.id}.jpg?v=")
    end

    it 'returns 401 for non-editors' do
      post "/api/v1/events/#{event.id}/upload_image", params: { image: png_upload }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/events/sync' do
    it 'enqueues the schedule sync' do
      expect do
        post '/api/v1/events/sync', headers: editor_headers
      end.to have_enqueued_job(Events::ScheduleSyncJob)
      expect(response).to have_http_status(:accepted)
      expect(json_response).to eq('queued' => true)
    end

    it 'returns 401 for non-editors' do
      post '/api/v1/events/sync', headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
