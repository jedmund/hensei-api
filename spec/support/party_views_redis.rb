# frozen_string_literal: true

# Party view specs use the real Redis under a test-only key prefix, cleared
# around each example.
module PartyViewsRedis
  PREFIX = 'test:party_views'

  def self.clear
    Sidekiq.redis do |redis|
      keys = redis.call('KEYS', "#{PREFIX}:*")
      redis.call('DEL', *keys) if keys.any?
    end
  end
end

RSpec.configure do |config|
  config.before(:each, :party_views) do
    stub_const('PartyViews::Recorder::PREFIX', PartyViewsRedis::PREFIX)
    PartyViewsRedis.clear
  end

  config.after(:each, :party_views) { PartyViewsRedis.clear }
end
