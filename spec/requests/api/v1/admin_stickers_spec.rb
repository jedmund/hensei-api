# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin stickers collection', type: :request do
  let(:path) { '/api/v1/admin/stickers' }
  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

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

  # Same position: the older one comes first (the prod copy has every row at 0)
  let!(:cleared) do
    create(:sticker, slug: 'cleared', meaning_en: 'Cleared', meaning_jp: '一番', position: 0,
                     image_key: 'icons/stickers/stamp1.png', image_key_jp: 'icons/stickers/stamp1.ja.png',
                     created_at: 2.days.ago)
  end
  let!(:fast) { create(:sticker, slug: 'fast', meaning_en: 'Fast', position: 0, created_at: 1.day.ago) }

  before do
    create(:sticker, :inactive, slug: 'retired', meaning_en: 'Old', position: 1)
    create_list(:party_sticker, 2, sticker: fast)
  end

  describe 'access' do
    it 'returns every sticker in picker order with the default fields' do
      body = fetch
      expect(response).to have_http_status(:ok)
      expect(slugs(body)).to eq(%w[cleared fast retired])
      expect(body['results'].first.keys).to match_array(
        %w[id slug meaning_en meaning_jp image_url image_url_ja position active]
      )
      expect(body['results'].first['image_url']).to start_with('icons/stickers/stamp1.png?v=')
      expect(body['results'].first['image_url_ja']).to start_with('icons/stickers/stamp1.ja.png?v=')
      expect(body['results'].second['image_url']).to be_nil
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

  describe 'q, filters and fields' do
    it 'matches slug and meanings' do
      fetch(q: '一番')
      expect(slugs).to eq(['cleared'])
      fetch(q: 'retir')
      expect(slugs).to eq(['retired'])
    end

    it 'filters by active' do
      fetch(filter: { active: 'false' })
      expect(slugs).to eq(['retired'])
    end

    it 'counts the teams each sticker is on' do
      body = fetch(fields: 'slug,given_count')
      counts = body['results'].to_h { |r| [r['slug'], r['given_count']] }
      expect(counts).to eq('cleared' => 0, 'fast' => 2, 'retired' => 0)
    end

    it 'sorts by any published column' do
      fetch(sort: '-meaning_en')
      expect(slugs).to eq(%w[retired fast cleared])
    end
  end

  describe 'conditional GET' do
    it 'returns 200 after a reorder or a sticker given' do
      fetch
      etag = response.headers['ETag']
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)

      create(:party_sticker, sticker: cleared)
      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:ok)
    end
  end
end

RSpec.describe 'Admin stickers schema', type: :request do
  let(:path) { '/api/v1/admin/stickers/schema' }
  let(:fixture) { Rails.root.join('spec/fixtures/admin_schema/stickers.json') }
  let(:schema) { Api::V1::Admin::StickersController.admin_collection_definition.schema }

  def auth_headers(role)
    user = create(:user, role: role)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  # The web app keeps a copy of this fixture (features/database/stickers).
  # Regenerate with UPDATE_ADMIN_SCHEMA_FIXTURES=1 after an intended change.
  it 'serves the schema to editors and matches the committed fixture' do
    get path, headers: auth_headers(7)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body

    if ENV['UPDATE_ADMIN_SCHEMA_FIXTURES']
      FileUtils.mkdir_p(fixture.dirname)
      File.write(fixture, "#{JSON.pretty_generate(body)}\n")
    end

    expect(body).to eq(JSON.parse(fixture.read))
  end

  it 'answers a revisit with 304' do
    headers = auth_headers(7)
    get path, headers: headers
    get path, headers: headers.merge('If-None-Match' => response.headers['ETag'])
    expect(response).to have_http_status(:not_modified)
  end

  it 'rejects a non-editor and a signed-out request' do
    get path, headers: auth_headers(3)
    expect(response).to have_http_status(:unauthorized)
    get path
    expect(response).to have_http_status(:unauthorized)
  end

  it 'publishes exactly what the strong params permit' do
    attrs = schema[:writable].to_h { |key, _shape| [key, '1'] }
    params = ActionController::Parameters.new(
      sticker: attrs.merge('id' => 'x', 'image_key' => 'x', 'image_key_jp' => 'x', 'created_at' => 'x')
    )
    controller = Api::V1::StickersController.new
    controller.params = params

    expect(controller.send(:sticker_params).to_h).to eq(attrs)
  end

  it 'publishes the slug and image key formats as JavaScript patterns' do
    slug = schema[:validators]['slug'].find { |rule| rule[:kind] == 'format' }
    expect(slug).to include(pattern: '^[a-z0-9]+(?:-[a-z0-9]+)*$')
    image = schema[:validators]['image_key'].find { |rule| rule[:kind] == 'format' }
    expect(Regexp.new(image[:pattern])).to match('icons/stickers/stamp1.ja.png')
  end
end
