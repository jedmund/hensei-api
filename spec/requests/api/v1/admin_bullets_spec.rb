# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin bullets collection', type: :request do
  let(:path) { '/api/v1/admin/bullets' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  let(:iron) do
    create(:bullet, name_en: 'Iron Bullet', name_jp: 'アイアンバレット', granblue_id: '91101', slug: 'iron-bullet',
                    bullet_type: 1, atk: 90, hits_all: false, order: 2)
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
    create(:bullet, name_en: 'Ghost Rifle', name_jp: 'ゴーストライフル', granblue_id: '92101', slug: 'ghost-rifle',
                    bullet_type: 2, atk: 300, hits_all: true, order: 21)
    iron
    create(:bullet, name_en: 'Rapid Bullet', name_jp: 'ラピッドバレット', granblue_id: '91201', slug: 'rapid-bullet',
                    bullet_type: 1, atk: 60, hits_all: false, order: 1, effect_en: 'Double attack up')
  end

  describe 'access' do
    it 'returns results for an editor, by type then order, with the default fields' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(['Rapid Bullet', 'Iron Bullet', 'Ghost Rifle'])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp slug bullet_type atk hits_all order effect_en effect_jp updated_at]
      )
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

  describe 'q and filters' do
    it 'matches names, slug and granblue_id' do
      fetch(q: 'ghost')
      expect(names).to eq(['Ghost Rifle'])
      fetch(q: 'アイアン')
      expect(names).to eq(['Iron Bullet'])
      fetch(q: 'rapid-b')
      expect(names).to eq(['Rapid Bullet'])
      fetch(q: '92101')
      expect(names).to eq(['Ghost Rifle'])
    end

    it 'filters by type, hits all and last edit' do
      fetch(filter: { bullet_type: '1' })
      expect(names).to eq(['Rapid Bullet', 'Iron Bullet'])
      fetch(filter: { hits_all: 'true' })
      expect(names).to eq(['Ghost Rifle'])
      iron.update_column(:updated_at, 40.days.ago)
      fetch(filter: { updated_at: { gte: 7.days.ago.iso8601 } })
      expect(names).to eq(['Rapid Bullet', 'Ghost Rifle'])
    end
  end

  describe 'sort and facets' do
    it 'sorts by any published column' do
      fetch(sort: '-atk')
      expect(names).to eq(['Ghost Rifle', 'Iron Bullet', 'Rapid Bullet'])
      fetch(sort: 'order')
      expect(names).to eq(['Rapid Bullet', 'Iron Bullet', 'Ghost Rifle'])
    end

    it 'counts types' do
      body = fetch(facets: 'bullet_type')
      expect(body['facets']['bullet_type']).to eq('1' => 2, '2' => 1)
    end
  end

  describe 'conditional GET' do
    it 'returns 304 for an unchanged collection and 200 after an edit' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      iron.update!(name_jp: 'アイアンバレットII')
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
