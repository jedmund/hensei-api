# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin character roles collection', type: :request do
  let(:path) { '/api/v1/admin/character_roles' }
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

  let!(:healer) { create(:grid_character_role, name_en: 'Healer', name_jp: 'ヒーラー', sort_order: 3) }
  let!(:attacker) { create(:grid_character_role, name_en: 'Attacker', name_jp: 'アタッカー', sort_order: 1) }
  let!(:defender) do
    create(:grid_character_role, name_en: 'Defender', name_jp: 'ディフェンダー', sort_order: 2,
                                 icon_key: 'images/grid_character_roles/d7734020-1031-406f-a6c9-b9690205b8f7.png')
  end

  before do
    GridCharacterRole.where.not(id: [healer, attacker, defender].map(&:id)).delete_all
  end

  describe 'access' do
    it 'returns every role in sort order with the default fields' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(names(body)).to eq(%w[Attacker Defender Healer])
      expect(body['results'].first.keys).to match_array(%w[id name_en name_jp sort_order icon_key])
      expect(body['meta']['total']).to eq(3)
    end

    it 'versions the icon key like the public role JSON' do
      row = fetch['results'].find { |r| r['id'] == defender.id }
      expect(row['icon_key']).to eq("#{defender.icon_key}?v=#{defender.updated_at.to_i}")
      expect(fetch['results'].find { |r| r['id'] == attacker.id }['icon_key']).to be_nil
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

  describe 'q, sort and fields' do
    it 'matches either name' do
      fetch(q: 'heal')
      expect(names).to eq(['Healer'])
      fetch(q: 'ディフェ')
      expect(names).to eq(['Defender'])
    end

    it 'sorts by name or reverse order' do
      fetch(sort: 'name_en')
      expect(names).to eq(%w[Attacker Defender Healer])
      fetch(sort: '-sort_order')
      expect(names).to eq(%w[Healer Defender Attacker])
    end

    it 'returns the requested fields only' do
      body = fetch(fields: 'name_en,sort_order')
      expect(body['results'].first.keys).to match_array(%w[id name_en sort_order])
    end

    it 'rejects an unknown sort or field' do
      fetch(sort: 'icon_key')
      expect(response).to have_http_status(:unprocessable_entity)
      fetch(fields: 'secret')
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'ETag' do
    it 'answers a revisit with 304 and refreshes after a reorder' do
      get path, headers: editor_headers
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      healer.update!(sort_order: 0)
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
      expect(names).to eq(%w[Healer Attacker Defender])
    end
  end
end
