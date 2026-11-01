# frozen_string_literal: true

require 'rails_helper'

# The database editor's weapon series, character series and awakening lists
# (GBF-143). The test database is seeded with real series and awakenings, so
# each example narrows to the rows it creates with a search.
RSpec.describe 'Admin series and awakenings collections', type: :request do
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def fetch(path, params = {}, headers = editor_headers)
    get path, params: params, headers: headers
    response.parsed_body
  end

  def slugs(body = response.parsed_body)
    body['results'].map { |r| r['slug'] }
  end

  describe 'GET /admin/weapon_series' do
    let(:path) { '/api/v1/admin/weapon_series' }
    let!(:alpha) do
      create(:weapon_series, slug: 'zz-alpha', name_en: 'Zz Alpha', order: 9002, augment_type: :ax,
                             has_weapon_keys: true, num_weapon_keys: 2)
    end
    let!(:bravo) { create(:weapon_series, slug: 'zz-bravo', name_en: 'Zz Bravo', order: 9001, extra: true) }

    before { create_list(:weapon, 2, weapon_series: alpha) }

    it 'lists by order with the default fields' do
      body = fetch(path, q: 'zz-')
      expect(response).to have_http_status(:ok)
      expect(slugs(body)).to eq(%w[zz-bravo zz-alpha])
      expect(body['results'].first.keys).to match_array(%w[id slug name_en name_jp order])
    end

    it 'filters on the augment type and flags, and counts augment types' do
      expect(slugs(fetch(path, q: 'zz-', filter: { augment_type: 'ax' }))).to eq(%w[zz-alpha])
      expect(slugs(fetch(path, q: 'zz-', filter: { extra: 'true' }))).to eq(%w[zz-bravo])
      expect(fetch(path, q: 'zz-', facets: 'augment_type')['facets']['augment_type'])
        .to eq('ax' => 1, 'no_augment' => 1)
    end

    it 'returns the flags, key slots and weapon count on request' do
      body = fetch(path, q: 'zz-alpha', fields: 'augment_type,has_weapon_keys,num_weapon_keys,weapon_count')
      expect(body['results'].first).to include('augment_type' => 'ax', 'has_weapon_keys' => true,
                                               'num_weapon_keys' => 2, 'weapon_count' => 2)
    end

    it 'rejects a non-editor' do
      fetch(path, {}, auth_headers(create(:user, role: 3)))
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /admin/character_series' do
    let(:path) { '/api/v1/admin/character_series' }
    let!(:alpha) { create(:character_series, slug: 'zz-alpha', name_en: 'Zz Alpha', order: 9002) }

    before do
      create(:character_series, slug: 'zz-bravo', name_en: 'Zz Bravo', order: 9001)
      create(:character).character_series_memberships.create!(character_series: alpha)
    end

    it 'lists by order and counts characters on request' do
      body = fetch(path, q: 'zz-', fields: 'slug,character_count')
      expect(response).to have_http_status(:ok)
      expect(slugs(body)).to eq(%w[zz-bravo zz-alpha])
      expect(body['results'].map { |r| r['character_count'] }).to eq([0, 1])
    end

    it 'sorts by name' do
      expect(slugs(fetch(path, q: 'zz-', sort: '-name_en'))).to eq(%w[zz-bravo zz-alpha])
    end

    it 'rejects a signed-out request' do
      fetch(path, {}, {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /admin/awakenings' do
    let(:path) { '/api/v1/admin/awakenings' }

    before do
      create(:awakening, slug: 'zz-weapon-b', name_en: 'Zz Weapon B', object_type: 'Weapon', order: 2)
      create(:awakening, slug: 'zz-weapon-a', name_en: 'Zz Weapon A', object_type: 'Weapon', order: 1)
      create(:awakening, slug: 'zz-character', name_en: 'Zz Character', object_type: 'Character', order: 5)
    end

    it 'lists by type, then order, with the default fields' do
      body = fetch(path, q: 'zz-')
      expect(response).to have_http_status(:ok)
      expect(slugs(body)).to eq(%w[zz-character zz-weapon-a zz-weapon-b])
      expect(body['results'].first.keys).to match_array(%w[id slug name_en name_jp object_type order updated_at])
    end

    it 'filters on the type and counts types' do
      expect(slugs(fetch(path, q: 'zz-', filter: { object_type: 'Weapon' }))).to eq(%w[zz-weapon-a zz-weapon-b])
      expect(fetch(path, q: 'zz-', facets: 'object_type')['facets']['object_type'])
        .to eq('Character' => 1, 'Weapon' => 2)
    end

    it 'rejects an unknown sort' do
      fetch(path, sort: 'weapon_count')
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
