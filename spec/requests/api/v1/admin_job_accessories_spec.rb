# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin job accessories collection', type: :request do
  let(:path) { '/api/v1/admin/job_accessories' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

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

  let!(:paladin) { create(:job, name_en: 'Paladin', accessory: true, accessory_type: 1) }
  let!(:manadiver) { create(:job, name_en: 'Manadiver', accessory: true, accessory_type: 2) }
  let!(:buckler) do
    create(:job_accessory, job: paladin, name_en: 'Buckler', name_jp: 'バックラー', granblue_id: '92002',
                           accessory_type: 1, rarity: 1, release_date: Date.new(2022, 3, 24))
  end
  let!(:obelisk) do
    create(:job_accessory, job: paladin, name_en: 'Obelisk', name_jp: 'オベリスク', granblue_id: '94013',
                           accessory_type: 1, rarity: 3, release_date: Date.new(2022, 1, 25))
  end
  let!(:burlona) do
    create(:job_accessory, job: manadiver, name_en: 'Burlona', name_jp: 'ブルロネ', granblue_id: '91',
                           accessory_type: 2, rarity: nil, release_date: Date.new(2022, 1, 25))
  end

  before do
    JobAccessory.where.not(id: [buckler, obelisk, burlona].map(&:id)).delete_all
  end

  describe 'access' do
    it 'returns results for an editor with the default fields and sort' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(%w[Buckler Obelisk Burlona])
      expect(body['results'].first.keys).to match_array(
        %w[id granblue_id name_en name_jp accessory_type rarity job release_date updated_at]
      )
      expect(body['results'].first['job']['id']).to eq(paladin.id)
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
    it 'matches names and granblue_id' do
      fetch(q: 'obel')
      expect(names).to eq(['Obelisk'])
      fetch(q: '92002')
      expect(names).to eq(['Buckler'])
    end

    it 'filters by type, rarity (or none), job, and release date' do
      fetch(filter: { accessory_type: '2' })
      expect(names).to eq(['Burlona'])
      fetch(filter: { rarity: '3,none' })
      expect(names).to eq(%w[Obelisk Burlona])
      fetch(filter: { job: paladin.id })
      expect(names).to eq(%w[Buckler Obelisk])
      fetch(filter: { release_date: { gte: '2022-02-01' } })
      expect(names).to eq(['Buckler'])
    end
  end

  describe 'sort and facets' do
    it 'sorts by any published column' do
      fetch(sort: '-release_date,name_en')
      expect(names).to eq(%w[Buckler Burlona Obelisk])
    end

    it 'counts types, rarities and jobs' do
      body = fetch(facets: 'accessory_type,rarity,job')
      expect(body['facets']['accessory_type']).to eq('1' => 2, '2' => 1)
      expect(body['facets']['rarity']).to eq('1' => 1, '3' => 1, 'none' => 1)
      expect(body['facets']['job']).to eq(paladin.id => 2, manadiver.id => 1)
    end
  end

  describe 'conditional GET' do
    it 'returns 304 for an unchanged collection and 200 after an edit' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      obelisk.update!(name_jp: 'オベリスクII')
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end
