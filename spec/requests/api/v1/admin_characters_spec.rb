# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin characters collection', type: :request do
  let(:path) { '/api/v1/admin/characters' }
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

  # Explicit dates throughout: latest_date is GREATEST of all four.
  def character(**attrs)
    create(:character, flb_date: nil, ulb_date: nil, transcendence_date: nil, **attrs)
  end

  let(:grand) { CharacterSeries.find_by(slug: 'grand') || create(:character_series, :grand) }
  let(:zodiac) { CharacterSeries.find_by(slug: 'zodiac') || create(:character_series, :zodiac) }

  let!(:alpha) do
    character(name_en: 'Alpha Knight', name_jp: 'アルファ', granblue_id: '3040000001', element: 1, rarity: 3,
              proficiency1: 1, proficiency2: nil, season: 1, gender: 1, release_date: Date.new(2020, 1, 1),
              updated_at: Time.zone.parse('2026-01-01 00:00'))
  end
  let!(:bravo) do
    character(name_en: 'Bravo Lancer', name_jp: '', granblue_id: '3040000002', element: 2, rarity: 3,
              proficiency1: 4, proficiency2: 1, season: nil, gender: 2, style_swap: true,
              release_date: Date.new(2022, 6, 1), updated_at: Time.zone.parse('2026-03-01 00:00'))
  end
  let!(:charlie) do
    character(name_en: 'Charlie Knight', name_jp: nil, granblue_id: '3030000003', element: 1, rarity: 2,
              proficiency1: 1, proficiency2: nil, season: 2, gender: 1, special: true,
              release_date: Date.new(2024, 6, 1), updated_at: Time.zone.parse('2026-02-01 00:00'))
  end
  let!(:delta) do
    # Both proficiency columns hold the same value: counted once in the facet.
    character(name_en: 'Delta Archer', name_jp: 'デルタ', granblue_id: '3040000004', element: 3, rarity: 3,
              proficiency1: 5, proficiency2: 5, season: 1, gender: 2, release_date: Date.new(2025, 1, 1),
              updated_at: Time.zone.parse('2026-02-01 00:00'))
  end

  before do
    # Drop the seeded characters (rolled back after each example) so counts are exact.
    keep = [alpha, bravo, charlie, delta].map(&:id)
    CharacterSeriesMembership.where.not(character_id: keep).delete_all
    CharacterSkill.where.not(character_id: keep).delete_all
    Character.where.not(id: keep).delete_all
    # Zodiac first, so the series field's ordering comes from series order.
    create(:character_series_membership, character: alpha, character_series: zodiac)
    create(:character_series_membership, character: alpha, character_series: grand)
    create(:character_series_membership, character: bravo, character_series: zodiac)
    create(:character_series_membership, character: delta, character_series: grand)
    create(:character_skill, character: alpha, position: 1)
    create(:character_skill, character: alpha, position: 2)
    create(:character_skill, character: delta, position: 1)
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['Delta Archer', 'Charlie Knight', 'Bravo Lancer', 'Alpha Knight'])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp element rarity proficiency1 proficiency2 style_swap
           release_date latest_date updated_at]
      )
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
      fetch(q: 'knight', sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Charlie Knight'])
    end

    it 'matches Japanese names and granblue_id' do
      fetch(q: 'デルタ')
      expect(names).to eq(['Delta Archer'])
      fetch(q: '3030000')
      expect(names).to eq(['Charlie Knight'])
    end
  end

  describe 'filters' do
    it 'filters by a list' do
      fetch(filter: { element: '1,3' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Charlie Knight', 'Delta Archer'])
      fetch(filter: { gender: '2' }, sort: 'name_en')
      expect(names).to eq(['Bravo Lancer', 'Delta Archer'])
    end

    it 'filters season by value or none' do
      fetch(filter: { season: '1' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Delta Archer'])
      fetch(filter: { season: 'none' })
      expect(names).to eq(['Bravo Lancer'])
    end

    it 'matches proficiency in either column' do
      fetch(filter: { proficiency: '1' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Bravo Lancer', 'Charlie Knight'])
      fetch(filter: { proficiency: '4,5' }, sort: 'name_en')
      expect(names).to eq(['Bravo Lancer', 'Delta Archer'])
    end

    it 'filters series by slug, id, or none through memberships' do
      fetch(filter: { series: 'zodiac' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Bravo Lancer'])
      fetch(filter: { series: "#{grand.id},none" }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Charlie Knight', 'Delta Archer'])
      fetch(filter: { series: 'none' })
      expect(names).to eq(['Charlie Knight'])
    end

    it 'returns a character in several matching series once' do
      body = fetch(filter: { series: 'grand,zodiac' }, sort: 'name_en')
      expect(names(body)).to eq(['Alpha Knight', 'Bravo Lancer', 'Delta Archer'])
      expect(body['meta']['total']).to eq(3)
    end

    it 'rejects series that match nothing' do
      body = fetch(filter: { series: 'grand,no-such-series' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('unknown series: no-such-series')

      missing = SecureRandom.uuid
      body = fetch(filter: { series: missing })
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq("unknown series: #{missing}")
    end

    it 'filters by booleans' do
      fetch(filter: { special: 'true' })
      expect(names).to eq(['Charlie Knight'])
      fetch(filter: { style_swap: 'true' })
      expect(names).to eq(['Bravo Lancer'])
      fetch(filter: { style_swap: 'false', flb: 'true' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Charlie Knight', 'Delta Archer'])
    end

    it 'filters by a date range' do
      fetch(filter: { release_date: { gte: '2022-01-01', lte: '2024-12-31' } }, sort: 'name_en')
      expect(names).to eq(['Bravo Lancer', 'Charlie Knight'])
    end

    it 'filters by a numeric range' do
      fetch(filter: { rarity: { lte: '2' } })
      expect(names).to eq(['Charlie Knight'])
    end

    it 'treats a bare date as the whole day for timestamps' do
      fetch(filter: { updated_at: { gte: '2026-02-01', lte: '2026-02-01' } }, sort: 'name_en')
      expect(names).to eq(['Charlie Knight', 'Delta Archer'])
    end

    it 'filters by data-quality flags, both ways' do
      fetch(filter: { missing_name_jp: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Lancer', 'Charlie Knight'])
      fetch(filter: { no_skills: 'true' }, sort: 'name_en')
      expect(names).to eq(['Bravo Lancer', 'Charlie Knight'])
      fetch(filter: { no_skills: 'false' }, sort: 'name_en')
      expect(names).to eq(['Alpha Knight', 'Delta Archer'])
    end

    it 'combines filters with q' do
      fetch(q: 'knight', filter: { rarity: '3', missing_name_jp: 'false', series: 'grand' })
      expect(names).to eq(['Alpha Knight'])
    end
  end

  describe 'sort' do
    it 'sorts by several columns' do
      fetch(sort: '-updated_at,name_en')
      expect(names).to eq(['Bravo Lancer', 'Charlie Knight', 'Delta Archer', 'Alpha Knight'])
      fetch(sort: 'element,-name_en')
      expect(names).to eq(['Charlie Knight', 'Alpha Knight', 'Bravo Lancer', 'Delta Archer'])
      fetch(sort: '-season,name_en')
      expect(names).to eq(['Charlie Knight', 'Alpha Knight', 'Delta Archer', 'Bravo Lancer'])
    end

    it 'sorts by the latest game date, counting uncaps' do
      alpha.update!(flb_date: Date.new(2026, 5, 1))
      body = fetch(sort: '-latest_date', fields: 'name_en,flb_date,latest_date')
      expect(names(body)).to eq(['Alpha Knight', 'Delta Archer', 'Charlie Knight', 'Bravo Lancer'])
      expect(body['results'].first).to include('flb_date' => '2026-05-01', 'latest_date' => '2026-05-01')
      fetch(sort: '-flb_date,name_en')
      expect(names.first).to eq('Alpha Knight')
    end
  end

  describe 'validation' do
    {
      'an unknown filter' => { filter: { edit_key: 'x' } },
      'a list on a range-only filter' => { filter: { updated_at: '2026-01-01' } },
      'a range on a list-only filter' => { filter: { series: { gte: '1' } } },
      'an unknown range key' => { filter: { rarity: { gt: '3' } } },
      'a non-integer value' => { filter: { proficiency: 'sabre' } },
      'a bad date' => { filter: { release_date: { gte: '2026-13-45' } } },
      'a non-boolean filter' => { filter: { style_swap: 'yes' } },
      'a non-boolean flag' => { filter: { no_skills: 'yes' } },
      'a non-object filter' => { filter: 'element' },
      'an unknown sort' => { sort: 'name_en,-max_atk' },
      'an unknown field' => { fields: 'name_en,edit_key' },
      'an unknown facet' => { facets: 'element,gender' }
    }.each do |label, params|
      it "returns 422 for #{label}" do
        body = fetch(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(body['error']).to be_a(String)
      end
    end
  end

  describe 'facets' do
    it 'counts values for the current filters, excluding each facet\'s own filter' do
      body = fetch(filter: { element: '1', rarity: '3' }, facets: 'element,rarity,season,proficiency,series')

      expect(names(body)).to eq(['Alpha Knight'])
      expect(body['facets']['element']).to eq('1' => 1, '2' => 1, '3' => 1)
      expect(body['facets']['rarity']).to eq('2' => 1, '3' => 1)
      expect(body['facets']['season']).to eq('1' => 1)
      expect(body['facets']['proficiency']).to eq('1' => 1)
      # One character in two series counts under each.
      expect(body['facets']['series']).to eq(grand.id => 1, zodiac.id => 1)
    end

    it 'counts memberships per series and characters without one under none' do
      body = fetch(facets: 'series,season,proficiency')
      expect(body['facets']['series']).to eq(grand.id => 2, zodiac.id => 2, 'none' => 1)
      expect(body['facets']['season']).to eq('1' => 2, '2' => 1, 'none' => 1)
      expect(body['facets']['proficiency']).to eq('1' => 3, '4' => 1, '5' => 1)
    end

    it 'applies the series filter to other facets and other filters to the series facet' do
      body = fetch(filter: { series: 'zodiac' }, facets: 'element,series')
      expect(body['facets']['element']).to eq('1' => 1, '2' => 1)
      expect(body['facets']['series']).to eq(grand.id => 2, zodiac.id => 2, 'none' => 1)

      body = fetch(filter: { element: '2' }, facets: 'series')
      expect(body['facets']['series']).to eq(zodiac.id => 1)
    end
  end

  describe 'fields' do
    it 'returns only the requested fields plus id, with series in series order' do
      body = fetch(fields: 'name_en,skill_count,series', sort: 'name_en')
      expect(body['results'].first).to eq(
        'id' => alpha.id, 'name_en' => 'Alpha Knight', 'skill_count' => 2,
        'series' => [
          { 'id' => grand.id, 'slug' => 'grand', 'name_en' => grand.name_en, 'name_jp' => grand.name_jp },
          { 'id' => zodiac.id, 'slug' => 'zodiac', 'name_en' => zodiac.name_en, 'name_jp' => zodiac.name_jp }
        ]
      )
      expect(body['results'].map { |r| r['skill_count'] }).to eq([2, 0, 0, 1])
      expect(body['results'].map { |r| r['series'].size }).to eq([2, 1, 0, 1])
    end

    it 'preloads series instead of querying per row' do
      create_list(:character, 5).each { |c| create(:character_series_membership, character: c, character_series: grand) }
      queries = []
      # Only row loads matter here, not the ETag's COUNT/MAX.
      callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "character_series" WHERE') }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        fetch(fields: 'series')
      end
      expect(response).to have_http_status(:ok)
      expect(queries.size).to eq(1)
    end
  end

  describe 'paging' do
    it 'reports meta and pages through results' do
      body = fetch(per: 3, page: 2, sort: 'name_en')
      expect(body['meta']).to eq('total' => 4, 'page' => 2, 'per' => 3, 'total_pages' => 2)
      expect(names(body)).to eq(['Delta Archer'])
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

      bravo.update!(name_en: 'Bravo Pikeman')
      expect(revalidate(etag)).to have_http_status(:ok)
    end

    it 'returns 200 after a series is renamed' do
      fetch(fields: 'series')
      etag = response.headers['ETag']

      travel(1.second) { grand.update!(name_en: 'Grand (renamed)') }
      expect(revalidate(etag, fields: 'series')).to have_http_status(:ok)
    end

    it 'returns 200 after a membership is added or removed' do
      fetch(fields: 'series')
      etag = response.headers['ETag']
      membership = create(:character_series_membership, character: charlie, character_series: grand)
      expect(revalidate(etag, fields: 'series')).to have_http_status(:ok)

      etag = response.headers['ETag']
      membership.destroy!
      expect(revalidate(etag, fields: 'series')).to have_http_status(:ok)
    end

    it 'returns 200 after a skill is added' do
      fetch(fields: 'skill_count')
      etag = response.headers['ETag']
      create(:character_skill, character: bravo, position: 1)
      expect(revalidate(etag, fields: 'skill_count')).to have_http_status(:ok)
    end
  end
end
