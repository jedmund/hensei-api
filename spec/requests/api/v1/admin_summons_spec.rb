# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin summons collection', type: :request do
  let(:path) { '/api/v1/admin/summons' }
  let(:editor) { create(:user, role: 7) }
  let(:editor_headers) { auth_headers(editor) }

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

  # The factory sets flb_date; latest_date is GREATEST of all four dates.
  def summon(**attrs)
    create(:summon, flb_date: nil, ulb_date: nil, transcendence_date: nil, **attrs)
  end

  let(:providence) { SummonSeries.find_by(slug: 'providence') || create(:summon_series, :providence) }
  let(:magna) { SummonSeries.find_by(slug: 'magna') || create(:summon_series, :magna) }

  let!(:alpha) do
    summon(name_en: 'Alpha Stone', name_jp: 'アルファ', granblue_id: '2040000001', element: 1, rarity: 3,
           summon_series: providence, subaura: true, max_level: 250, release_date: Date.new(2020, 1, 1),
           updated_at: Time.zone.parse('2026-01-01 00:00'))
  end
  let!(:bravo) do
    summon(name_en: 'Bravo Stone', name_jp: '', granblue_id: '2040000002', element: 2, rarity: 3,
           summon_series: magna, support_eligible: false, max_level: 150, release_date: Date.new(2022, 6, 1),
           updated_at: Time.zone.parse('2026-03-01 00:00'))
  end
  let!(:charlie) do
    summon(name_en: 'Charlie Gem', name_jp: nil, granblue_id: '2030000003', element: 1, rarity: 2,
           summon_series: nil, max_level: 100, release_date: Date.new(2024, 6, 1),
           updated_at: Time.zone.parse('2026-02-01 00:00'))
  end
  let!(:delta) do
    summon(name_en: 'Delta Stone', name_jp: 'デルタ', granblue_id: '2040000004', element: 3, rarity: 3,
           summon_series: providence, limit: true, max_level: 200, release_date: Date.new(2025, 1, 1),
           updated_at: Time.zone.parse('2026-02-01 00:00'))
  end

  before do
    # Drop the seeded summons (rolled back after each example) so counts are exact.
    keep = [alpha, bravo, charlie, delta]
    SummonAura.where.not(summon_granblue_id: keep.map(&:granblue_id)).delete_all
    Summon.where.not(id: keep.map(&:id)).delete_all
    create(:summon_aura, summon_granblue_id: alpha.granblue_id, slot: 'main')
    create(:summon_aura, summon_granblue_id: alpha.granblue_id, slot: 'sub')
    create(:summon_aura, summon_granblue_id: delta.granblue_id, slot: 'main')
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['Delta Stone', 'Charlie Gem', 'Bravo Stone', 'Alpha Stone'])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp element rarity series_id series_slug release_date latest_date updated_at]
      )
      expect(body['results'].first['series_slug']).to eq('providence')
      expect(body).not_to have_key('facets')
    end

    it 'rejects a signed-in user below the editor role' do
      fetch({}, auth_headers(create(:user, role: 3)))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      fetch({}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'q' do
    it 'matches English names case-insensitively' do
      fetch(q: 'STONE', sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Bravo Stone', 'Delta Stone'])
    end

    it 'matches Japanese names and granblue_id' do
      fetch(q: 'デルタ')
      expect(names).to eq(['Delta Stone'])
      fetch(q: '2030000')
      expect(names).to eq(['Charlie Gem'])
    end
  end

  describe 'filters' do
    it 'filters by a list' do
      fetch(filter: { element: '1,3' }, sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Charlie Gem', 'Delta Stone'])
    end

    it 'filters series by slug, id, or none' do
      fetch(filter: { series: 'magna' })
      expect(names).to eq(['Bravo Stone'])
      fetch(filter: { series: "#{providence.id},none" }, sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Charlie Gem', 'Delta Stone'])
    end

    it 'rejects series that match nothing' do
      body = fetch(filter: { series: 'magna,no-such-series' })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to eq('unknown series: no-such-series')

      missing = SecureRandom.uuid
      body = fetch(filter: { series: missing })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to eq("unknown series: #{missing}")
    end

    it 'filters by booleans' do
      fetch(filter: { subaura: 'true' })
      expect(names).to eq(['Alpha Stone'])
      fetch(filter: { limit: 'true' })
      expect(names).to eq(['Delta Stone'])
      fetch(filter: { support_eligible: 'false' })
      expect(names).to eq(['Bravo Stone'])
    end

    it 'filters by a date range' do
      fetch(filter: { release_date: { gte: '2022-01-01', lte: '2024-12-31' } }, sort: 'name_en')
      expect(names).to eq(['Bravo Stone', 'Charlie Gem'])
    end

    it 'filters by a numeric range' do
      fetch(filter: { rarity: { lte: '2' } })
      expect(names).to eq(['Charlie Gem'])
    end

    it 'treats a bare date as the whole day for timestamps' do
      fetch(filter: { updated_at: { gte: '2026-02-01', lte: '2026-02-01' } }, sort: 'name_en')
      expect(names).to eq(['Charlie Gem', 'Delta Stone'])
    end

    it 'filters by data-quality flags, both ways' do
      fetch(filter: { missing_name_jp: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Stone', 'Charlie Gem'])
      fetch(filter: { no_auras: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Stone', 'Charlie Gem'])
      fetch(filter: { no_auras: 'false' }, sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Delta Stone'])
      # All four have FLB: only Bravo (SSR, 150) has the standard max level
      fetch(filter: { caps_mismatch: 'true' }, sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Charlie Gem', 'Delta Stone'])
      fetch(filter: { caps_mismatch: 'false' }, sort: 'name_en')
      expect(names).to eq(['Bravo Stone'])
    end

    it 'combines filters with q' do
      fetch(q: 'stone', filter: { rarity: '3', missing_name_jp: 'false', series: 'providence' }, sort: 'name_en')
      expect(names).to eq(['Alpha Stone', 'Delta Stone'])
    end
  end

  describe 'sort' do
    it 'sorts by several columns' do
      fetch(sort: '-updated_at,name_en')
      expect(names).to eq(['Bravo Stone', 'Charlie Gem', 'Delta Stone', 'Alpha Stone'])
      fetch(sort: 'element,-name_en')
      expect(names).to eq(['Charlie Gem', 'Alpha Stone', 'Bravo Stone', 'Delta Stone'])
      fetch(sort: '-max_level')
      expect(names).to eq(['Alpha Stone', 'Delta Stone', 'Bravo Stone', 'Charlie Gem'])
    end

    it 'sorts by the latest game date, counting uncaps' do
      alpha.update!(flb_date: Date.new(2026, 5, 1))
      body = fetch(sort: '-latest_date', fields: 'name_en,flb_date,latest_date')
      expect(names(body)).to eq(['Alpha Stone', 'Delta Stone', 'Charlie Gem', 'Bravo Stone'])
      expect(body['results'].first).to include('flb_date' => '2026-05-01', 'latest_date' => '2026-05-01')
      fetch(sort: '-flb_date,name_en')
      expect(names.first).to eq('Alpha Stone')
    end
  end

  describe 'validation' do
    {
      'an unknown filter' => { filter: { edit_key: 'x' } },
      'a list on a range-only filter' => { filter: { updated_at: '2026-01-01' } },
      'a range on a list-only filter' => { filter: { series: { gte: '1' } } },
      'an unknown range key' => { filter: { rarity: { gt: '3' } } },
      'a non-integer value' => { filter: { element: 'fire' } },
      'a bad date' => { filter: { release_date: { gte: '2026-13-45' } } },
      'a non-boolean flag' => { filter: { no_auras: 'yes' } },
      'a non-object filter' => { filter: 'element' },
      'an unknown sort' => { sort: 'name_en,-max_atk' },
      'an unknown field' => { fields: 'name_en,edit_key' },
      'an unknown facet' => { facets: 'element,max_level' }
    }.each do |label, params|
      it "returns 422 for #{label}" do
        body = fetch(params)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(body['error']).to be_a(String)
      end
    end
  end

  describe 'facets' do
    it 'counts values for the current filters, excluding each facet\'s own filter' do
      body = fetch(filter: { element: '1', rarity: '3' }, facets: 'element,rarity,series')

      expect(names(body)).to eq(['Alpha Stone'])
      expect(body['facets']['element']).to eq('1' => 1, '2' => 1, '3' => 1)
      expect(body['facets']['rarity']).to eq('2' => 1, '3' => 1)
      expect(body['facets']['series']).to eq(providence.id => 1)
    end

    it 'counts missing values under none' do
      body = fetch(facets: 'series')
      expect(body['facets']['series']).to eq(providence.id => 2, magna.id => 1, 'none' => 1)
    end
  end

  describe 'fields' do
    it 'returns only the requested fields plus id' do
      body = fetch(fields: 'name_en,aura_count,series_name_en,max_level', sort: 'name_en')
      expect(body['results'].first).to eq(
        'id' => alpha.id, 'name_en' => 'Alpha Stone', 'aura_count' => 2,
        'series_name_en' => providence.name_en, 'max_level' => 250
      )
      expect(body['results'].map { |r| r['aura_count'] }).to eq([2, 0, 0, 1])
    end

    it 'preloads series instead of querying per row' do
      create_list(:summon, 5, summon_series: magna)
      queries = []
      # Only row loads matter here, not the ETag's COUNT/MAX.
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "summon_series" WHERE') }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        fetch(fields: 'series_slug,series_name_jp')
      end
      expect(response).to have_http_status(:ok)
      expect(queries.size).to eq(1)
    end
  end

  describe 'paging' do
    it 'reports meta and pages through results' do
      body = fetch(per: 3, page: 2, sort: 'name_en')
      expect(body['meta']).to eq('total' => 4, 'page' => 2, 'per' => 3, 'total_pages' => 2)
      expect(names(body)).to eq(['Delta Stone'])
    end

    it 'defaults to 50 and caps per at 200' do
      expect(fetch['meta']['per']).to eq(50)
      expect(fetch(per: 1000)['meta']['per']).to eq(200)
    end
  end

  describe 'conditional GET' do
    def revalidate(etag, params = { sort: 'name_en' })
      get path, params: params, headers: editor_headers.merge('If-None-Match' => etag)
      response
    end

    it 'returns 304 for an unchanged collection and 200 after an edit' do
      fetch(sort: 'name_en')
      etag = response.headers['ETag']
      expect(etag).to be_present

      expect(revalidate(etag)).to have_http_status(:not_modified)
      expect(revalidate(etag, sort: 'name_jp')).to have_http_status(:ok)

      bravo.update!(name_en: 'Bravo Rock')
      expect(revalidate(etag)).to have_http_status(:ok)
    end

    it 'returns 200 after a series is renamed' do
      fetch(fields: 'series_name_en')
      etag = response.headers['ETag']

      travel(1.second) { magna.update!(name_en: 'Magna (renamed)') }
      expect(revalidate(etag, fields: 'series_name_en')).to have_http_status(:ok)
    end

    it 'returns 200 after an aura is added' do
      fetch(fields: 'aura_count')
      etag = response.headers['ETag']
      create(:summon_aura, summon_granblue_id: bravo.granblue_id, slot: 'main')
      expect(revalidate(etag, fields: 'aura_count')).to have_http_status(:ok)
    end
  end
end
