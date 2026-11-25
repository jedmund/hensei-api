# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Events', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:member) { create(:user, role: 1) }
  let(:editor_headers) { bearer_headers(editor) }
  let(:member_headers) { bearer_headers(member) }
  let(:curator_headers) { bearer_headers(create(:user, role: 6)) }

  def json_response
    response.parsed_body
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
      expect(json_response['events'].pluck('id')).to eq([current.id])

      get '/api/v1/events', params: { scope: 'upcoming' }
      expect(json_response['events'].pluck('id')).to eq([upcoming.id])

      get '/api/v1/events', params: { scope: 'past' }
      expect(json_response['events'].pluck('id')).to eq([past.id])

      get '/api/v1/events', params: { kind: 'unite_and_fight' }
      expect(json_response['events'].pluck('id')).to eq([upcoming.id])
    end

    it 'renders the event shape with linked raids and integer elements' do
      get '/api/v1/events', params: { scope: 'current' }
      event = json_response['events'].first
      expect(event).to include('kind' => 'story_event', 'status' => 'approved', 'element' => nil,
                               'advantage_element' => nil, 'image_url' => nil)
      expect(event['raids'].pluck('id')).to eq([raid.id])
      expect(event).not_to have_key('source_refs')
      expect(event).not_to have_key('event_number')

      get '/api/v1/events', params: { kind: 'unite_and_fight' }
      gw = json_response['events'].first
      expect(gw['element']).to eq(GranblueEnums::ELEMENTS[:Water])
      expect(gw['advantage_element']).to eq(GranblueEnums::ELEMENTS[:Earth])
    end

    it 'lets editors filter by status and see editor fields' do
      get '/api/v1/events', params: { status: 'draft' }, headers: editor_headers
      expect(json_response['events'].pluck('id')).to eq([draft.id])
      expect(json_response['events'].first).to include('source_refs' => {}, 'source_payload' => {})

      get '/api/v1/events', params: { status: 'all' }, headers: editor_headers
      expect(json_response['events'].size).to eq(4)
    end

    it 'lets curators see every event with editor fields' do
      get '/api/v1/events', params: { status: 'all' }, headers: curator_headers
      expect(json_response['events'].size).to eq(4)
      expect(json_response['events'].first).to include('source_refs' => {})
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

    it 'returns a hidden event to curators' do
      event = create(:event, :hidden)
      get "/api/v1/events/#{event.id}", headers: curator_headers
      expect(response).to have_http_status(:ok)
      expect(json_response).to include('id' => event.id, 'source_refs' => {})
    end
  end

  describe 'POST /api/v1/events' do
    let(:raids) { create_list(:raid, 2) }
    let(:params) do
      { event: { name_en: 'Unite and Fight', name_jp: '古戦場', kind: 'unite_and_fight', element: 'fire',
                 event_number: 80, starts_at: 3.days.from_now.iso8601, ends_at: 10.days.from_now.iso8601,
                 raid_ids: [raids.second.id, raids.first.id] } }
    end

    it 'creates an approved event with ordered raids' do
      post '/api/v1/events', params: params, headers: editor_headers

      expect(response).to have_http_status(:created)
      expect(json_response).to include('status' => 'approved', 'kind' => 'unite_and_fight',
                                       'element' => GranblueEnums::ELEMENTS[:Fire])
      expect(json_response['raids'].pluck('id')).to eq([raids.second.id, raids.first.id])
    end

    it 'accepts event_number for Unite and Fight' do
      post '/api/v1/events', params: params.deep_merge(event: { event_number: 81 }), headers: editor_headers
      expect(response).to have_http_status(:created)
      expect(json_response['event_number']).to eq(81)
    end

    it 'requires event_number for Unite and Fight' do
      post '/api/v1/events', params: params.deep_merge(event: { event_number: nil }), headers: editor_headers,
                             as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('event_number')
    end

    it 'accepts a null event_number for other kinds' do
      story = params.deep_merge(event: { kind: 'story_event', element: nil, event_number: nil })
      post '/api/v1/events', params: story, headers: editor_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(json_response).to include('kind' => 'story_event', 'event_number' => nil)
    end

    it 'sets the series and falls back to its banner' do
      post '/api/v1/events', params: params.deep_merge(event: { series: 'unite_and_fight' }),
                             headers: editor_headers
      expect(response).to have_http_status(:created)
      expect(json_response).to include('series' => 'unite_and_fight',
                                       'image_url' => 'events/series/unite_and_fight.webp')
    end

    it 'rejects an unknown series' do
      post '/api/v1/events', params: params.deep_merge(event: { series: 'tower_of_babyl' }), headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'accepts the element as an integer' do
      post '/api/v1/events', params: params.deep_merge(event: { element: 3 }), headers: editor_headers
      expect(json_response['element']).to eq(3)
    end

    it 'requires an element for Unite and Fight' do
      post '/api/v1/events', params: params.deep_merge(event: { element: '' }), headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an unknown raid with 422 and creates nothing' do
      bad = params.deep_merge(event: { raid_ids: ['00000000-0000-0000-0000-000000000000'] })
      expect { post '/api/v1/events', params: bad, headers: editor_headers }.not_to change(Event, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('raid_ids')
    end

    it 'sets the day each raid opens on' do
      post '/api/v1/events', params: params.deep_merge(event: { raid_unlock_days: { raids.first.id => 2 } }),
                             headers: editor_headers, as: :json
      expect(response).to have_http_status(:created)
      by_id = json_response['raids'].index_by { |raid| raid['id'] }
      expect(by_id[raids.first.id]['unlock_day']).to eq(2)
      midnight = Time.zone.parse(json_response['starts_at']).in_time_zone('Asia/Tokyo').beginning_of_day
      expect(Time.zone.parse(by_id[raids.first.id]['unlocks_at'])).to eq(midnight + 2.days)
      expect(by_id[raids.second.id]).to include('unlock_day' => nil, 'unlocks_at' => nil)
    end

    it 'accepts a null raid_unlock_days, as the editor sends with no days' do
      post '/api/v1/events', params: params.deep_merge(event: { raid_unlock_days: nil }),
                             headers: editor_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(json_response['raids'].pluck('unlock_day')).to eq([nil, nil])
    end

    it 'opens scheduled Guild War raids on their day' do
      nm200 = create(:raid, slug: 'nm200')
      ex = create(:raid, slug: 'ex')
      post '/api/v1/events', params: params.deep_merge(event: { raid_ids: [ex.id, nm200.id] }),
                             headers: editor_headers, as: :json
      expect(response).to have_http_status(:created)
      event = Event.find(json_response['id'])
      rows = event.event_raids.index_by(&:raid_id)
      expect(rows[ex.id].unlock_day).to be_nil
      expect(rows[nm200.id].unlock_day).to eq(3)
    end

    it 'rejects an end before the start' do
      post '/api/v1/events', params: params.deep_merge(event: { ends_at: 1.day.ago.iso8601 }), headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 401 for non-editors' do
      post '/api/v1/events', params: params, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 for curators' do
      expect { post '/api/v1/events', params: params, headers: curator_headers }.not_to change(Event, :count)
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
      expect(json_response['raids'].pluck('id')).to eq([raid.id])
    end

    it 'stores and returns the external links' do
      links = { wiki_en: 'Exo Diablo Crucible', gamewith: '412345', kamigame: 'イベント/天上劇団もぐら座/index' }
      put "/api/v1/events/#{event.id}", params: { event: links }, headers: editor_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response).to include('wiki_en' => 'Exo Diablo Crucible', 'gamewith' => '412345',
                                       'kamigame' => 'イベント/天上劇団もぐら座/index')
      expect(event.reload.gamewith).to eq('412345')
    end

    it 'stores a second boss element and returns both advantages' do
      put "/api/v1/events/#{event.id}",
          params: { event: { kind: 'records_of_the_ten', element: 4, second_element: 'light' } },
          headers: editor_headers, as: :json
      expect(response).to have_http_status(:ok)
      el = GranblueEnums::ELEMENTS
      expect(json_response).to include('element' => el[:Wind], 'second_element' => el[:Light],
                                       'advantage_elements' => [el[:Fire], el[:Dark]])
    end

    it 'rejects a GameWith link that is not an article number' do
      put "/api/v1/events/#{event.id}", params: { event: { gamewith: 'https://gamewith.jp/x' } },
                                        headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(event.reload.gamewith).to be_nil
    end

    it 'requires event_number for a Guild War' do
      gw = create(:gw_event, event_number: 84)
      put "/api/v1/events/#{gw.id}", params: { event: { event_number: nil } }, headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(gw.reload.event_number).to eq(84)
    end

    it 'accepts a null event_number for other kinds' do
      put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed', event_number: nil } },
                                        headers: editor_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(event.reload.event_number).to be_nil
    end

    it 'edits the number of a Guild War' do
      gw = create(:gw_event, event_number: 84)
      put "/api/v1/events/#{gw.id}", params: { event: { event_number: 85 } }, headers: editor_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['event_number']).to eq(85)
      expect(gw.reload.event_number).to eq(85)
    end

    it 'rejects a Guild War number that is taken' do
      create(:gw_event, event_number: 84)
      gw = create(:gw_event, event_number: 85)
      put "/api/v1/events/#{gw.id}", params: { event: { event_number: 84 } }, headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'replaces raid links when raid_ids is given' do
      other = create(:raid)
      put "/api/v1/events/#{event.id}", params: { event: { raid_ids: [other.id] } }, headers: editor_headers
      expect(json_response['raids'].pluck('id')).to eq([other.id])
    end

    it 'returns 422 (not 404) for an unknown raid' do
      put "/api/v1/events/#{event.id}", params: { event: { raid_ids: ['nope'] } }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(event.reload.event_raids.map(&:raid_id)).to eq([raid.id])
    end

    describe 'raid_unlock_days' do
      def day_of(row_raid = raid)
        event.event_raids.reload.find_by(raid: row_raid).unlock_day
      end

      def put_days(days, headers: editor_headers, **extra)
        put "/api/v1/events/#{event.id}", params: { event: { raid_unlock_days: days, **extra } },
                                          headers: headers, as: :json
      end

      it 'sets the hour raids open at' do
        put "/api/v1/events/#{event.id}", params: { event: { raid_unlock_hour: 5 } }, headers: editor_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['raid_unlock_hour']).to eq(5)
        expect(event.reload.raid_unlock_hour).to eq(5)
      end

      it 'sets and returns the day a raid opens on' do
        put_days({ raid.id => 2 })
        expect(response).to have_http_status(:ok)
        expect(json_response['raids'].first['unlock_day']).to eq(2)
        expect(Time.zone.parse(json_response['raids'].first['unlocks_at'])).to be_within(1.second).of(event.starts_at + 2.days)
        expect(day_of).to eq(2)
      end

      it 'accepts a day as a string' do
        put_days({ raid.id => '3' })
        expect(day_of).to eq(3)
      end

      it 'clears a blank day and keeps raids left out' do
        other = create(:raid)
        create(:event_raid, event: event, raid: other, position: 1, unlock_day: 2)
        event.event_raids.find_by(raid: raid).update!(unlock_day: 2)
        put_days({ raid.id => '' })
        expect(response).to have_http_status(:ok)
        expect(day_of).to be_nil
        expect(day_of(other)).to eq(2)
      end

      it 'keeps days for a null raid_unlock_days' do
        event.event_raids.first.update!(unlock_day: 2)
        put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed', raid_unlock_days: nil } },
                                          headers: editor_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(json_response['name']['en']).to eq('Renamed')
        expect(day_of).to eq(2)
      end

      it 'keeps days when raid_unlock_days is omitted' do
        event.event_raids.first.update!(unlock_day: 2)
        put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed' } }, headers: editor_headers, as: :json
        expect(day_of).to eq(2)
      end

      it 'sets days for raids linked in the same request' do
        other = create(:raid)
        put_days({ other.id => 2 }, raid_ids: [raid.id, other.id])
        expect(response).to have_http_status(:ok)
        expect(json_response['raids'].pluck('unlock_day')).to eq([nil, 2])
      end

      it 'rejects a raid that is not linked, and changes nothing' do
        put_days({ create(:raid).id => 2 }, name_en: 'Renamed')
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('raid_unlock_days')
        expect(event.reload.name_en).not_to eq('Renamed')
      end

      it 'rejects a day that is not a whole number' do
        put_days({ raid.id => '1.5' })
        expect(response).to have_http_status(:unprocessable_content)
        expect(day_of).to be_nil
      end

      it 'rejects day 0 and a day after the event' do
        put_days({ raid.id => 0 })
        expect(response).to have_http_status(:unprocessable_content)

        put_days({ raid.id => 30 })
        expect(response).to have_http_status(:unprocessable_content)
        expect(day_of).to be_nil
      end

      it 'returns 401 for members, and changes nothing' do
        put_days({ raid.id => 2 }, headers: member_headers)
        expect(response).to have_http_status(:unauthorized)
        expect(day_of).to be_nil
      end
    end

    it 'returns 401 for non-editors and curators' do
      put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed' } }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)

      put "/api/v1/events/#{event.id}", params: { event: { name_en: 'Renamed' } }, headers: curator_headers
      expect(response).to have_http_status(:unauthorized)
      expect(event.reload.name_en).not_to eq('Renamed')
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

    it 'returns 401 for non-editors and curators' do
      post "/api/v1/events/#{event.id}/approve", headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      post "/api/v1/events/#{event.id}/approve", headers: curator_headers
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

    it 'stores the Japanese banner under events/<id>.ja, next to the English one' do
      upload = Rack::Test::UploadedFile.new(StringIO.new(jpeg_bytes), 'image/jpeg', original_filename: 'b.jpg')
      post "/api/v1/events/#{event.id}/upload_image", params: { image: upload, language: 'ja' },
                                                      headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(IconStorage).to have_received(:put)
        .with("events/#{event.id}.ja.jpg", kind_of(String), content_type: 'image/jpeg')
      expect(event.reload).to have_attributes(image_key_jp: "events/#{event.id}.ja.jpg", image_key: nil)
      expect(json_response['image_url_ja']).to start_with("events/#{event.id}.ja.jpg?v=")
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
