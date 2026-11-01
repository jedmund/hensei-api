# frozen_string_literal: true

# Contract tests for the schemas of the database editor's weapon series,
# character series and awakenings (GBF-143):
#   GET /api/v1/admin/{weapon_series,character_series,awakenings}/schema
#
# Each response must equal spec/fixtures/admin_schema/<resource>.json. The web
# app keeps a copy of each fixture and checks its definition against it, so a
# change here means copying the new fixture to hensei-web too.
#
# After an intended change to a Definition, PERMITTED, the enums or the model's
# validators, regenerate the fixtures with:
#
#   UPDATE_ADMIN_SCHEMA_FIXTURES=1 bundle exec rspec spec/requests/api/v1/admin_series_schemas_spec.rb
require 'rails_helper'

RSpec.describe 'Admin series and awakenings schemas', type: :request do
  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  let(:editor_headers) { auth_headers(create(:user, role: 7)) }

  {
    'weapon_series' => [Api::V1::Admin::WeaponSeriesController, Api::V1::WeaponSeriesController,
                        :weapon_series, :weapon_series_params],
    'character_series' => [Api::V1::Admin::CharacterSeriesController, Api::V1::CharacterSeriesController,
                           :character_series, :character_series_params],
    'awakenings' => [Api::V1::Admin::AwakeningsController, Api::V1::AwakeningsController,
                     :awakening, :awakening_params]
  }.each do |resource, (admin_controller, controller_class, param_key, params_method)|
    describe resource do
      let(:path) { "/api/v1/admin/#{resource}/schema" }
      let(:fixture) { Rails.root.join("spec/fixtures/admin_schema/#{resource}.json") }
      let(:schema) { admin_controller.admin_collection_definition.schema }

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

      it 'publishes exactly what the strong params permit' do
        attrs = schema[:writable].to_h { |key, _shape| [key, '1'] }
        params = ActionController::Parameters.new(
          param_key => attrs.merge('id' => 'x', 'user_id' => 'x', 'created_at' => 'x')
        )

        controller = controller_class.new
        controller.params = params
        expect(controller.send(params_method).to_h).to eq(attrs)
      end

      it 'publishes the slug format as a JavaScript pattern' do
        format = schema[:validators]['slug'].find { |rule| rule[:kind] == 'format' }
        expect(format).to include(pattern: '^[a-z0-9]+(?:-[a-z0-9]+)*$', flags: '')
      end
    end
  end

  it 'publishes the enum values the models accept' do
    weapon_series = Api::V1::Admin::WeaponSeriesController.admin_collection_definition.schema
    inclusion = weapon_series[:validators]['augment_type'].find { |rule| rule[:kind] == 'inclusion' }
    expect(inclusion[:in]).to match_array(weapon_series[:enums]['augment_type'].keys)

    awakenings = Api::V1::Admin::AwakeningsController.admin_collection_definition.schema
    inclusion = awakenings[:validators]['object_type'].find { |rule| rule[:kind] == 'inclusion' }
    expect(inclusion[:in]).to eq(awakenings[:enums]['object_type'].values)
  end
end
