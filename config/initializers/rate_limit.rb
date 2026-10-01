# frozen_string_literal: true

# Shared store for controller rate limits (ActionController::RateLimiting).
# Redis keeps the counters consistent across Puma workers and instances; the
# test suite uses an in-memory store that is cleared before each example.
Rails.application.config.x.rate_limit_store =
  if Rails.env.test?
    ActiveSupport::Cache::MemoryStore.new
  else
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      namespace: 'rate_limit'
    )
  end
