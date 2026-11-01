# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin weapons collection', type: :request do
  let(:path) { '/api/v1/admin/weapons' }
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

  # The canonical seed data includes these series and some weapons.
  let(:opus) { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus) }
  let(:grand) { WeaponSeries.find_by(slug: 'grand') || create(:weapon_series, :grand) }

  let!(:alpha) do
    create(:weapon, name_en: 'Alpha Blade', name_jp: 'アルファ', granblue_id: '1040000001', element: 1, rarity: 4,
                    proficiency: 1, weapon_series: opus, release_date: Date.new(2020, 1, 1), flb_date: nil,
                    updated_at: Time.zone.parse('2026-01-01 00:00'))
  end
  let!(:bravo) do
    create(:weapon, name_en: 'Bravo Spear', name_jp: '', granblue_id: '1040000002', element: 2, rarity: 4,
                    proficiency: 4, weapon_series: grand, release_date: Date.new(2022, 6, 1), flb_date: nil,
                    updated_at: Time.zone.parse('2026-03-01 00:00'))
  end
  let!(:charlie) do
    create(:weapon, name_en: 'Charlie Blade', name_jp: nil, granblue_id: '1030000003', element: 1, rarity: 3,
                    proficiency: 1, weapon_series: nil, release_date: Date.new(2024, 6, 1), flb_date: nil,
                    updated_at: Time.zone.parse('2026-02-01 00:00'))
  end
  let!(:delta) do
    create(:weapon, name_en: 'Delta Bow', name_jp: 'デルタ', granblue_id: '1040000004', element: 3, rarity: 4,
                    proficiency: 5, weapon_series: opus, release_date: Date.new(2025, 1, 1), flb_date: nil,
                    updated_at: Time.zone.parse('2026-02-01 00:00'))
  end

  before do
    # Drop the seeded weapons (rolled back after each example) so counts are exact.
    keep = [alpha, bravo, charlie, delta].map(&:id)
    WeaponAwakening.where.not(weapon_id: keep).delete_all
    Weapon.where.not(id: keep).delete_all
    create(:weapon_skill, weapon: alpha, position: 1)
    create(:weapon_skill, weapon: alpha, position: 2)
    create(:weapon_skill, weapon: delta, position: 1)
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['Delta Bow', 'Charlie Blade', 'Bravo Spear', 'Alpha Blade'])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp element rarity proficiency series_id series_slug release_date updated_at]
      )
      expect(body['results'].first['series_slug']).to eq('dark-opus')
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
      fetch(q: 'blade', sort: 'name_en')
      expect(names).to eq(['Alpha Blade', 'Charlie Blade'])
    end

    it 'matches Japanese names and granblue_id' do
      fetch(q: 'デルタ')
      expect(names).to eq(['Delta Bow'])
      fetch(q: '1030000')
      expect(names).to eq(['Charlie Blade'])
    end

    it 'treats LIKE wildcards literally' do
      fetch(q: '%')
      expect(names).to be_empty
    end
  end

  describe 'filters' do
    it 'filters by a list' do
      fetch(filter: { element: '1,3' }, sort: 'name_en')
      expect(names).to eq(['Alpha Blade', 'Charlie Blade', 'Delta Bow'])
    end

    it 'filters series by slug, id, or none' do
      fetch(filter: { series: 'grand' })
      expect(names).to eq(['Bravo Spear'])
      fetch(filter: { series: "#{opus.id},none" }, sort: 'name_en')
      expect(names).to eq(['Alpha Blade', 'Charlie Blade', 'Delta Bow'])
    end

    it 'rejects series that match nothing' do
      body = fetch(filter: { series: 'grand,no-such-series' })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to eq('unknown series: no-such-series')

      missing = SecureRandom.uuid
      body = fetch(filter: { series: missing })
      expect(response).to have_http_status(:unprocessable_entity)
      expect(body['error']).to eq("unknown series: #{missing}")
    end

    it 'filters by a date range' do
      fetch(filter: { release_date: { gte: '2022-01-01', lte: '2024-12-31' } }, sort: 'name_en')
      expect(names).to eq(['Bravo Spear', 'Charlie Blade'])
    end

    it 'filters by a numeric range' do
      fetch(filter: { rarity: { lte: '3' } })
      expect(names).to eq(['Charlie Blade'])
    end

    it 'treats a bare date as the whole day for timestamps' do
      fetch(filter: { updated_at: { gte: '2026-02-01', lte: '2026-02-01' } }, sort: 'name_en')
      expect(names).to eq(['Charlie Blade', 'Delta Bow'])
    end

    it 'filters by data-quality flags, both ways' do
      fetch(filter: { missing_name_jp: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Spear', 'Charlie Blade'])
      fetch(filter: { no_skills: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Spear', 'Charlie Blade'])
      fetch(filter: { no_skills: 'false' }, sort: 'name_en')
      expect(names).to eq(['Alpha Blade', 'Delta Bow'])
    end

    it 'combines filters with q' do
      fetch(q: 'blade', filter: { rarity: '4', missing_name_jp: 'false' })
      expect(names).to eq(['Alpha Blade'])
    end
  end

  describe 'sort' do
    it 'sorts by several columns' do
      fetch(sort: '-updated_at,name_en')
      expect(names).to eq(['Bravo Spear', 'Charlie Blade', 'Delta Bow', 'Alpha Blade'])
      fetch(sort: 'element,-name_en')
      expect(names).to eq(['Charlie Blade', 'Alpha Blade', 'Bravo Spear', 'Delta Bow'])
    end

    it 'sorts by the latest game date, counting uncaps' do
      alpha.update!(flb_date: Date.new(2026, 5, 1))
      body = fetch(sort: '-latest_date', fields: 'name_en,flb_date,latest_date')
      expect(names(body)).to eq(['Alpha Blade', 'Delta Bow', 'Charlie Blade', 'Bravo Spear'])
      expect(body['results'].first).to include('flb_date' => '2026-05-01', 'latest_date' => '2026-05-01')
      fetch(sort: '-flb_date,name_en')
      expect(names.first).to eq('Alpha Blade')
    end
  end

  describe 'validation' do
    {
      'an unknown filter' => { filter: { edit_key: 'x' } },
      'a list on a range-only filter' => { filter: { updated_at: '2026-01-01' } },
      'a range on a list-only filter' => { filter: { granblue_id: { gte: '1' } } },
      'an unknown range key' => { filter: { rarity: { gt: '3' } } },
      'a non-integer value' => { filter: { element: 'fire' } },
      'a bad date' => { filter: { release_date: { gte: '2026-13-45' } } },
      'a non-boolean flag' => { filter: { no_skills: 'yes' } },
      'a non-object filter' => { filter: 'element' },
      'an unknown sort' => { sort: 'name_en,-max_atk' },
      'an unknown field' => { fields: 'name_en,edit_key' },
      'an unknown facet' => { facets: 'element,max_atk' }
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
      body = fetch(filter: { element: '1', rarity: '4' }, facets: 'element,rarity,proficiency,series')

      expect(names(body)).to eq(['Alpha Blade'])
      # element ignores filter[element] but keeps filter[rarity]
      expect(body['facets']['element']).to eq('1' => 1, '2' => 1, '3' => 1)
      # rarity ignores filter[rarity] but keeps filter[element]
      expect(body['facets']['rarity']).to eq('3' => 1, '4' => 1)
      # proficiency keeps both filters
      expect(body['facets']['proficiency']).to eq('1' => 1)
      expect(body['facets']['series']).to eq(opus.id => 1)
    end

    it 'counts missing values under none' do
      body = fetch(facets: 'series')
      expect(body['facets']['series']).to eq(opus.id => 2, grand.id => 1, 'none' => 1)
    end
  end

  describe 'fields' do
    it 'returns only the requested fields plus id' do
      body = fetch(fields: 'name_en,skill_count,series_name_en', sort: 'name_en')
      expect(body['results'].first).to eq(
        'id' => alpha.id, 'name_en' => 'Alpha Blade', 'skill_count' => 2, 'series_name_en' => opus.name_en
      )
      expect(body['results'].map { |r| r['skill_count'] }).to eq([2, 0, 0, 1])
    end

    it 'preloads series instead of querying per row' do
      create_list(:weapon, 5, weapon_series: grand)
      queries = []
      # Only row loads matter here, not the ETag's COUNT/MAX.
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "weapon_series" WHERE') }
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
      expect(names(body)).to eq(['Delta Bow'])
    end

    it 'defaults to 50 and caps per at 200' do
      expect(fetch['meta']['per']).to eq(50)
      expect(fetch(per: 1000)['meta']['per']).to eq(200)
    end
  end

  describe 'conditional GET' do
    it 'returns 304 for an unchanged collection and 200 after an edit' do
      fetch(sort: 'name_en')
      etag = response.headers['ETag']
      expect(etag).to be_present

      get path, params: { sort: 'name_en' }, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      get path, params: { sort: 'name_jp' }, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)

      bravo.update!(name_en: 'Bravo Lance')
      get path, params: { sort: 'name_en' }, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 after a series is renamed' do
      fetch(fields: 'series_name_en')
      etag = response.headers['ETag']

      travel(1.second) { grand.update!(name_en: 'Grand Weapons (renamed)') }
      get path, params: { fields: 'series_name_en' }, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
