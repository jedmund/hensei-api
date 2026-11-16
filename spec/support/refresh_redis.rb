# frozen_string_literal: true

# CacheEpoch and GachaSimulation::Refresh keep their state in the real Redis.
# Specs use test-only prefixes, so they never touch a running app's state,
# and examples tagged :refresh_redis start and end with them cleared.
module RefreshRedis
  PREFIX = 'test:refresh'

  def self.clear
    Sidekiq.redis do |redis|
      keys = redis.call('KEYS', "#{PREFIX}:*")
      redis.call('DEL', *keys) if keys.any?
    end
  end
end

RSpec.configure do |config|
  config.before do
    stub_const('CacheEpoch::PREFIX', "#{RefreshRedis::PREFIX}:epoch")
    stub_const('GachaSimulation::Refresh::PREFIX', "#{RefreshRedis::PREFIX}:gacha")
  end
  config.before(:each, :refresh_redis) { RefreshRedis.clear }
  config.after(:each, :refresh_redis) { RefreshRedis.clear }
end
