# frozen_string_literal: true

# Contract test for GET /api/v1/admin/artifact_skills/schema (GBF-143).
#
# The response must equal spec/fixtures/admin_schema/artifact_skills.json. The
# web app keeps a copy of that fixture and checks its artifact skills schema
# against it, so a change here means copying the new fixture to hensei-web too.
#
# After an intended change to the artifact skills Definition, PERMITTED, the
# enums or ArtifactSkill's validators, regenerate the fixture with:
#
#   UPDATE_ADMIN_SCHEMA_FIXTURES=1 bundle exec rspec spec/requests/api/v1/admin_artifact_skills_schema_spec.rb
require 'rails_helper'

RSpec.describe 'Admin artifact skills schema', type: :request do
  let(:path) { '/api/v1/admin/artifact_skills/schema' }
  let(:fixture) { Rails.root.join('spec/fixtures/admin_schema/artifact_skills.json') }

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

    it 'is exactly what the artifact skills strong params permit' do
      writable = Api::V1::Admin::ArtifactSkillsController.admin_collection_definition.schema[:writable]
      attrs = writable.to_h { |key, shape| [key, sample(shape)] }
      extra = { 'id' => 'x', 'score_category' => '1', 'created_at' => 'x' }
      params = ActionController::Parameters.new(attrs.merge(extra))

      controller = Api::V1::ArtifactSkillsController.new
      controller.params = params
      permitted = controller.send(:artifact_skill_params).to_h

      expect(permitted).to eq(attrs)
    end
  end

  describe 'enums and validators' do
    let(:schema) { Api::V1::Admin::ArtifactSkillsController.admin_collection_definition.schema }

    it 'publishes the values the model accepts' do
      %w[skill_group polarity].each do |name|
        inclusion = schema[:validators][name].find { |rule| rule[:kind] == 'inclusion' }
        expect(inclusion[:in]).to eq(schema[:enums][name].keys)
      end
      score = schema[:validators]['score_category'].find { |rule| rule[:kind] == 'inclusion' }
      expect(score[:in]).to eq(schema[:enums]['score_category'].values)
    end

    it 'publishes the modifier as a positive whole number' do
      numericality = schema[:validators]['modifier'].find { |rule| rule[:kind] == 'numericality' }
      expect(numericality).to include(only_integer: true, greater_than: 0)
    end
  end
end
