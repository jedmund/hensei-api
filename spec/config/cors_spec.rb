# frozen_string_literal: true

require 'spec_helper'
require 'active_support/string_inquirer'
require 'rack/cors'
require 'rack/mock'

RSpec.describe 'CORS configuration' do
  let(:phone_origin) { 'http://192.168.1.50:5174' }

  def cors_for(environment, extra_origins: '')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DEV_CORS_ORIGINS', '').and_return(extra_origins)

    middleware = double('middleware')
    cors = nil
    allow(middleware).to receive(:insert_before).with(0, Rack::Cors) do |_, klass, &configuration|
      cors = klass.new(->(_) { [200, { 'content-type' => 'text/plain' }, ['ok']] }, &configuration)
    end

    # Evaluate the real initializer with a fresh middleware stack for each environment.
    namespace = Module.new
    namespace.const_set(:Rails, double('Rails',
                                       env: ActiveSupport::StringInquirer.new(environment),
                                       application: double('application', config: double('config', middleware: middleware))))
    initializer = File.expand_path('../../config/initializers/cors.rb', __dir__)
    namespace.module_eval(File.read(initializer), initializer)
    cors
  end

  def preflight(cors, origin)
    Rack::MockRequest.new(cors).options('/api/v1/parties',
                                        'HTTP_ORIGIN' => origin,
                                        'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
                                        'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'authorization,content-type')
  end

  it 'preserves localhost access and denies LAN origins by default' do
    cors = cors_for('development')

    expect(preflight(cors, 'http://localhost:5174')['access-control-allow-origin']).to eq('http://localhost:5174')
    expect(preflight(cors, phone_origin)['access-control-allow-origin']).to be_nil
  end

  it 'allows explicitly configured origins with credentials and authorization headers in development' do
    second_origin = 'http://10.0.0.50:5174'
    cors = cors_for('development', extra_origins: " #{phone_origin}, , #{second_origin}, ")

    [phone_origin, second_origin].each do |origin|
      response = preflight(cors, origin)
      expect(response['access-control-allow-origin']).to eq(origin)
      expect(response['access-control-allow-credentials']).to eq('true')
      expect(response['access-control-allow-headers']).to include('authorization')
    end
  end

  it 'matches the configured scheme, host and port exactly' do
    cors = cors_for('development', extra_origins: phone_origin)
    other_origins = ['https://192.168.1.50:5174', 'http://192.168.1.51:5174',
                     'http://192.168.1.50:5173', 'http://192.168.1.50.evil.example:5174']

    other_origins.each do |origin|
      expect(preflight(cors, origin)['access-control-allow-origin']).to be_nil
    end
  end

  %w[test staging production].each do |environment|
    it "ignores development origins in #{environment}" do
      cors = cors_for(environment, extra_origins: phone_origin)

      expect(preflight(cors, phone_origin)['access-control-allow-origin']).to be_nil
    end
  end

  it 'preserves the production frontend origin' do
    cors = cors_for('production', extra_origins: phone_origin)

    expect(preflight(cors, 'https://granblue.team')['access-control-allow-origin']).to eq('https://granblue.team')
  end
end
