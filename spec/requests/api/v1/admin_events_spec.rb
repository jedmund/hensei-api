# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin events collection', type: :request do
  let(:path) { '/api/v1/admin/events' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  let!(:gw) do
    create(:event, :unite_and_fight, name_en: 'Unite and Fight #70', name_jp: '星の古戦場', event_number: 70,
                                     element: 'Water', series: 'unite_and_fight',
                                     starts_at: Time.zone.parse('2026-09-21 10:00'),
                                     ends_at: Time.zone.parse('2026-09-28 15:00'))
  end
  let!(:barrage) do
    create(:event, :dread_barrage, name_en: 'Dread Barrage', name_jp: 'ドレッドバラージュ', element: 'Fire',
                                   starts_at: Time.zone.parse('2026-08-01 10:00'),
                                   ends_at: Time.zone.parse('2026-08-08 10:00'))
  end

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def fetch(params = {}, headers = editor_headers)
    get path, params: params, headers: headers
    response.parsed_body
  end

  def names(body = response.parsed_body)
    body['results'].map { |r| r['name_en'] }
  end

  before do
    create(:event, :draft, name_en: 'A Story', name_jp: nil, element: nil,
                           starts_at: Time.zone.parse('2026-10-01 10:00'), ends_at: Time.zone.parse('2026-10-10 10:00'))
    create(:event_raid, event: gw, raid: create(:raid), position: 0)
    create(:event_raid, event: gw, raid: create(:raid), position: 1)
  end

  describe 'access' do
    it 'returns results for an editor with the default fields, newest first' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['A Story', 'Unite and Fight #70', 'Dread Barrage'])
      expect(body['results'].first.keys).to match_array(
        %w[id name_en name_jp kind element event_number starts_at ends_at raid_count]
      )
      expect(body['results'].second).to include(
        'kind' => 'unite_and_fight', 'element' => GranblueEnums::ELEMENTS[:Water], 'event_number' => 70,
        'raid_count' => 2
      )
      expect(body['results'].first).to include('element' => nil, 'raid_count' => 0)
    end

    it 'serves curators, who read events to pick teams for them' do
      fetch({}, auth_headers(create(:user, role: 6)))
      expect(response).to have_http_status(:ok)
      get "#{path}/schema", headers: auth_headers(create(:user, role: 6))
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a signed-in user below the curator role' do
      fetch({}, auth_headers(create(:user, role: 3)))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      fetch({}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'q' do
    it 'matches English and Japanese names' do
      fetch(q: 'unite')
      expect(names).to eq(['Unite and Fight #70'])
      fetch(q: 'ドレッド')
      expect(names).to eq(['Dread Barrage'])
    end
  end

  describe 'filters' do
    it 'filters by kind, series and status names' do
      fetch(filter: { kind: 'unite_and_fight,dread_barrage' })
      expect(names).to eq(['Unite and Fight #70', 'Dread Barrage'])
      fetch(filter: { series: 'none' })
      expect(names).to eq(['A Story', 'Dread Barrage'])
      fetch(filter: { status: 'draft' })
      expect(names).to eq(['A Story'])
    end

    it 'filters the boss element by its integer, or none' do
      fetch(filter: { element: GranblueEnums::ELEMENTS[:Fire].to_s })
      expect(names).to eq(['Dread Barrage'])
      fetch(filter: { element: "#{GranblueEnums::ELEMENTS[:Water]},none" })
      expect(names).to eq(['A Story', 'Unite and Fight #70'])
    end

    it 'filters by number and dates' do
      fetch(filter: { event_number: '70' })
      expect(names).to eq(['Unite and Fight #70'])
      fetch(filter: { starts_at: { gte: '2026-09-01' } })
      expect(names).to eq(['A Story', 'Unite and Fight #70'])
    end
  end

  describe 'sort' do
    it 'sorts by name and number' do
      fetch(sort: 'name_en')
      expect(names).to eq(['A Story', 'Dread Barrage', 'Unite and Fight #70'])
      fetch(sort: '-event_number,name_en')
      expect(names).to eq(['Unite and Fight #70', 'A Story', 'Dread Barrage'])
    end
  end

  describe 'facets' do
    it 'counts kinds by name and elements by integer' do
      body = fetch(filter: { kind: 'story_event' }, facets: 'kind,element,status,series')
      expect(body['facets']['kind']).to eq('story_event' => 1, 'unite_and_fight' => 1, 'dread_barrage' => 1)
      expect(body['facets']['element']).to eq('none' => 1)
      expect(body['facets']['status']).to eq('draft' => 1)

      body = fetch(facets: 'element,series')
      expect(body['facets']['element']).to eq(
        GranblueEnums::ELEMENTS[:Water].to_s => 1, GranblueEnums::ELEMENTS[:Fire].to_s => 1, 'none' => 1
      )
      expect(body['facets']['series']).to eq('unite_and_fight' => 1, 'none' => 2)
    end
  end

  describe 'fields' do
    it 'returns the requested fields' do
      body = fetch(fields: 'status,series,image_key', filter: { kind: 'unite_and_fight' })
      expect(body['results']).to eq(
        [{ 'id' => gw.id, 'status' => 'approved', 'series' => 'unite_and_fight', 'image_key' => nil }]
      )
    end
  end

  describe 'conditional GET' do
    it 'returns 200 after the linked raids change' do
      fetch
      etag = response.headers['ETag']
      travel(1.second) { create(:event_raid, event: barrage, raid: create(:raid)) }
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
