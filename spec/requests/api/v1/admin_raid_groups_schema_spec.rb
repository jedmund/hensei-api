# frozen_string_literal: true

# Contract test for GET /api/v1/admin/raid_groups/schema (GBF-143).
#
# The response must equal spec/fixtures/admin_schema/raid_groups.json. The web
# app keeps a copy of that fixture and checks its raid groups schema against it,
# so a change here means copying the new fixture to hensei-web too.
#
# After an intended change to the raid groups Definition, PERMITTED, the enums or
# RaidGroup's validators, regenerate the fixture with:
#
#   UPDATE_ADMIN_SCHEMA_FIXTURES=1 bundle exec rspec spec/requests/api/v1/admin_raid_groups_schema_spec.rb
require 'rails_helper'

RSpec.describe 'Admin raid groups schema', type: :request do
  let(:path) { '/api/v1/admin/raid_groups/schema' }
  let(:fixture) { Rails.root.join('spec/fixtures/admin_schema/raid_groups.json') }

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
      get path, headers: auth_headers(create(:user, role: 6))
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

    it 'is exactly what the raid groups strong params permit' do
      writable = Api::V1::Admin::RaidGroupsController.admin_collection_definition.schema[:writable]
      attrs = writable.to_h { |key, shape| [key, sample(shape)] }
      params = ActionController::Parameters.new(raid_group: attrs.merge('id' => 'x', 'user_id' => 'x', 'created_at' => 'x'))

      controller = Api::V1::RaidGroupsController.new
      controller.params = params
      permitted = controller.send(:raid_group_params).to_h

      expect(permitted).to eq(attrs)
    end
  end

  describe 'enums and validators' do
    let(:schema) { Api::V1::Admin::RaidGroupsController.admin_collection_definition.schema }

    it 'publishes the sections the model accepts, Farming (0) included' do
      inclusion = schema[:validators]['section'].find { |rule| rule[:kind] == 'inclusion' }
      expect(inclusion[:in]).to eq(schema[:enums]['section'].values)
      expect(schema[:enums]['section']).to include('farming' => 0)
    end
  end
end
