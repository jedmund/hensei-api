# frozen_string_literal: true

# GachaSimulation::Refresh keeps its state in the real Redis. Specs use a
# test-only prefix, so they never touch a running app's refresh state, and
# examples tagged :gacha_refresh start and end with it cleared.
module GachaRefreshRedis
  PREFIX = 'test:gacha_refresh'

  def self.clear
    Sidekiq.redis do |redis|
      keys = redis.call('KEYS', "#{PREFIX}:*")
      redis.call('DEL', *keys) if keys.any?
    end
  end
end

RSpec.configure do |config|
  config.before { stub_const('GachaSimulation::Refresh::PREFIX', GachaRefreshRedis::PREFIX) }
  config.before(:each, :gacha_refresh) { GachaRefreshRedis.clear }
  config.after(:each, :gacha_refresh) { GachaRefreshRedis.clear }
end
