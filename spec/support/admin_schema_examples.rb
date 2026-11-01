# frozen_string_literal: true

# The contract of GET /api/v1/admin/<resource>/schema (GBF-143), shared by the
# resources whose strong params are a plain params.permit(*PERMITTED).
#
# The response must equal spec/fixtures/admin_schema/<resource>.json. The web
# app keeps a copy of that fixture and checks its definition against it, so a
# change here means copying the new fixture to hensei-web too. After an intended
# change to the Definition, PERMITTED, the enums or the model's validators,
# regenerate the fixture with UPDATE_ADMIN_SCHEMA_FIXTURES=1.
#
#   it_behaves_like 'an admin schema', 'jobs', Api::V1::JobsController, :job_update_params
RSpec.shared_examples 'an admin schema' do |resource, controller_class, params_method|
  let(:path) { "/api/v1/admin/#{resource}/schema" }
  let(:fixture) { Rails.root.join("spec/fixtures/admin_schema/#{resource}.json") }
  let(:schema) { "Api::V1::Admin::#{resource.camelize}Controller".constantize.admin_collection_definition.schema }

  def schema_headers(role)
    user = create(:user, role: role)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  it 'serves the schema to editors and matches the committed fixture' do
    get path, headers: schema_headers(7)
    expect(response).to have_http_status(:ok)
    body = response.parsed_body

    if ENV['UPDATE_ADMIN_SCHEMA_FIXTURES']
      FileUtils.mkdir_p(fixture.dirname)
      File.write(fixture, "#{JSON.pretty_generate(body)}\n")
    end

    expect(body).to eq(JSON.parse(fixture.read))
  end

  it 'answers a revisit with 304' do
    headers = schema_headers(7)
    get path, headers: headers
    get path, headers: headers.merge('If-None-Match' => response.headers['ETag'])
    expect(response).to have_http_status(:not_modified)
  end

  it 'rejects a non-editor and a signed-out request' do
    get path, headers: schema_headers(3)
    expect(response).to have_http_status(:unauthorized)
    get path
    expect(response).to have_http_status(:unauthorized)
  end

  it 'publishes exactly what the strong params permit' do
    attrs = schema[:writable].to_h { |key, _shape| [key, '1'] }
    controller = controller_class.new
    controller.params = ActionController::Parameters.new(attrs.merge('id' => 'x', 'user_id' => 'x', 'created_at' => 'x'))

    expect(controller.send(params_method).to_h).to eq(attrs)
  end

  it 'publishes the enum values the model accepts' do
    schema[:validators].each do |name, rules|
      inclusion = rules.find { |rule| rule[:kind] == 'inclusion' }
      next unless inclusion && schema[:enums][name]

      expect(inclusion[:in]).to eq(schema[:enums][name].values)
    end
  end
end
