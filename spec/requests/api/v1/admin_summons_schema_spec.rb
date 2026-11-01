# frozen_string_literal: true

# Contract test for GET /api/v1/admin/summons/schema (GBF-143).
#
# The response must equal spec/fixtures/admin_schema/summons.json. The web
# app keeps a copy of that fixture and checks its summons schema against it,
# so a change here means copying the new fixture to hensei-web too.
#
# After an intended change to the summons Definition, PERMITTED, the enums or
# Summon's validators, regenerate the fixture with:
#
#   UPDATE_ADMIN_SCHEMA_FIXTURES=1 bundle exec rspec spec/requests/api/v1/admin_summons_schema_spec.rb
require 'rails_helper'

RSpec.describe 'Admin summons schema', type: :request do
  let(:path) { '/api/v1/admin/summons/schema' }
  let(:fixture) { Rails.root.join('spec/fixtures/admin_schema/summons.json') }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  describe 'access' do
    it 'serves the schema to editors' do
      get path, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq(%w[search filters flags sorts default_sort fields default_fields
                                                 writable enums validators])
    end

    it 'rejects a non-editor' do
      get path, headers: auth_headers(create(:user, role: 3))
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a signed-out request' do
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'contract' do
    it 'matches the committed fixture' do
      get path, headers: editor_headers
      body = response.parsed_body

      if ENV['UPDATE_ADMIN_SCHEMA_FIXTURES']
        FileUtils.mkdir_p(fixture.dirname)
        File.write(fixture, "#{JSON.pretty_generate(body)}\n")
      end

      expect(body).to eq(JSON.parse(fixture.read))
    end

    it 'answers a revisit with 304' do
      get path, headers: editor_headers
      etag = response.headers['ETag']

      get path, headers: editor_headers.merge('If-None-Match' => etag)
      expect(response).to have_http_status(:not_modified)
    end
  end

  describe 'writable' do
    # Every writable key with a value of its shape, plus fields that must
    # never be mass-assigned.
    def sample(shape)
      { 'scalar' => '1', 'array' => %w[1 2] }.fetch(shape)
    end

    it 'is exactly what the summons strong params permit' do
      writable = Api::V1::Admin::SummonsController.admin_collection_definition.schema[:writable]
      attrs = writable.to_h { |key, shape| [key, sample(shape)] }
      params = ActionController::Parameters.new(summon: attrs.merge('id' => 'x', 'user_id' => 'x', 'created_at' => 'x'))

      controller = Api::V1::SummonsController.new
      controller.params = params
      permitted = controller.send(:summon_params).to_h

      expect(permitted).to eq(attrs)
    end
  end

  describe 'enums and validators' do
    let(:schema) { Api::V1::Admin::SummonsController.admin_collection_definition.schema }

    it 'publishes the values the model accepts' do
      rules = schema[:validators]
      %w[element rarity].each do |name|
        inclusion = rules[name].find { |rule| rule[:kind] == 'inclusion' }
        expect(inclusion[:in]).to eq(schema[:enums][name].values)
      end
    end

    it 'publishes the granblue_id format as a JavaScript pattern' do
      format = schema[:validators]['granblue_id'].find { |rule| rule[:kind] == 'format' }
      expect(format).to include(pattern: '^\d{10}$', flags: '')
    end

    it 'never offers Null as an element' do
      expect(schema[:enums]['element'].values).not_to include(0)
    end
  end
end
