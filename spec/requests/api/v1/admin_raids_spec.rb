# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin raids collection', type: :request do
  let(:path) { '/api/v1/admin/raids' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  let(:omega) { create(:raid_group, name_en: 'Omega', section: 1, order: 2, hl: false, extra: false) }
  let(:primarchs) { create(:raid_group, name_en: 'Primarchs', section: 1, order: 1, hl: true, extra: true) }
  let(:farming) { create(:raid_group, name_en: 'Farming', section: 0, order: 0, hl: false, extra: false) }

  let!(:tiamat) do
    create(:raid, group: omega, slug: 'tiamat-omega', name_en: 'Tiamat Omega', name_jp: 'ティアマト・マグナ',
                  element: 4, level: 50, player_count: 18, released_at: Date.new(2014, 3, 10))
  end
  let!(:colossus) do
    create(:raid, group: omega, slug: 'colossus-omega', name_en: 'Colossus Omega', name_jp: 'コロッサス・マグナ',
                  element: 1, level: 70, player_count: 30, released_at: nil)
  end
  let!(:michael) do
    create(:raid, group: primarchs, slug: 'michael', name_en: 'Michael', name_jp: 'ミカエル',
                  element: 1, level: 150, player_count: 6, extra: nil, released_at: Date.new(2018, 1, 1))
  end
  let!(:angel) do
    create(:raid, group: farming, slug: 'angel-halo', name_en: 'Angel Halo', name_jp: 'エンジェル・ヘイロー',
                  element: 0, level: nil, player_count: 1, extra: true)
  end

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def fetch(params = {}, headers = editor_headers)
    get path, params: params, headers: headers
    response.parsed_body
  end

  def slugs(body = response.parsed_body)
    body['results'].map { |r| r['slug'] }
  end

  before do
    # Drop raids other data seeds (rolled back after each example) so counts are exact.
    Character.where.not(solomonis_zone_id: nil).update_all(solomonis_zone_id: nil)
    EventRaid.delete_all
    Raid.where.not(id: [tiamat, colossus, michael, angel].map(&:id)).delete_all
  end

  describe 'access' do
    it 'returns results for an editor with the default fields, in the raid picker order' do
      body = fetch
      expect(response).to have_http_status(:ok)
      # Section, then group order, then element and level
      expect(slugs(body)).to eq(%w[angel-halo michael colossus-omega tiamat-omega])
      expect(body['results'].first.keys).to match_array(
        %w[id slug name_en name_jp level element player_count group updated_at]
      )
      expect(body['results'].second['group']).to eq(
        'id' => primarchs.id, 'name_en' => 'Primarchs', 'name_jp' => primarchs.name_jp, 'section' => 1, 'order' => 1
      )
    end

    it 'rejects a signed-in user below the editor role' do
      fetch({}, auth_headers(create(:user, role: 6)))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      fetch({}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'q' do
    it 'matches names and slugs' do
      fetch(q: 'omega', sort: 'slug')
      expect(slugs).to eq(%w[colossus-omega tiamat-omega])
      fetch(q: 'ミカエル')
      expect(slugs).to eq(%w[michael])
    end
  end

  describe 'filters' do
    it 'filters by element, group and player count' do
      fetch(filter: { element: '1' }, sort: 'slug')
      expect(slugs).to eq(%w[colossus-omega michael])
      fetch(filter: { group: omega.id }, sort: 'slug')
      expect(slugs).to eq(%w[colossus-omega tiamat-omega])
      fetch(filter: { player_count: '1,6' }, sort: 'slug')
      expect(slugs).to eq(%w[angel-halo michael])
    end

    it 'filters by level and release date ranges' do
      fetch(filter: { level: { gte: '70' } }, sort: 'slug')
      expect(slugs).to eq(%w[colossus-omega michael])
      fetch(filter: { released_at: { lte: '2015-01-01' } })
      expect(slugs).to eq(%w[tiamat-omega])
    end

    it "flags HL raids by their group's flag" do
      fetch(filter: { hl: 'true' })
      expect(slugs).to eq(%w[michael])
      fetch(filter: { hl: 'false' }, sort: 'slug')
      expect(slugs).to eq(%w[angel-halo colossus-omega tiamat-omega])
    end

    it "flags Extra raids by their own flag, else their group's" do
      tiamat.update!(extra: false)
      fetch(filter: { extra: 'true' }, sort: 'slug')
      expect(slugs).to eq(%w[angel-halo michael])
      fetch(filter: { extra: 'false' }, sort: 'slug')
      expect(slugs).to eq(%w[colossus-omega tiamat-omega])
    end

    it 'rejects a group that is not a UUID' do
      fetch(filter: { group: 'omega' })
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'sort' do
    it 'sorts by group section and order, both ways' do
      fetch(sort: '-group_order,slug')
      expect(slugs).to eq(%w[colossus-omega tiamat-omega michael angel-halo])
      fetch(sort: '-group_section,-level')
      expect(slugs).to eq(%w[michael colossus-omega tiamat-omega angel-halo])
    end

    it 'sorts by plain columns' do
      fetch(sort: '-released_at,slug')
      expect(slugs).to eq(%w[michael tiamat-omega angel-halo colossus-omega])
    end
  end

  describe 'facets' do
    it 'counts element, group and player count' do
      body = fetch(filter: { element: '1' }, facets: 'element,group,player_count')
      expect(body['facets']['element']).to eq('0' => 1, '1' => 2, '4' => 1)
      expect(body['facets']['group']).to eq(omega.id => 1, primarchs.id => 1)
      expect(body['facets']['player_count']).to eq('6' => 1, '30' => 1)
    end
  end

  describe 'fields' do
    it 'returns the requested fields' do
      body = fetch(fields: 'slug,group_id,released_at,extra', filter: { group: primarchs.id })
      expect(body['results']).to eq(
        [{ 'id' => michael.id, 'slug' => 'michael', 'group_id' => primarchs.id,
           'released_at' => '2018-01-01', 'extra' => nil }]
      )
    end
  end

  describe 'conditional GET' do
    it 'returns 200 after a group changes' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      travel(1.second) { omega.update!(order: 9) }
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
