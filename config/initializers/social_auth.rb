# frozen_string_literal: true

# Cache for login providers' signing keys (JWKS). Redis shares them across Puma
# workers and instances; the test suite uses an in-memory store.
Rails.application.config.x.social_auth_cache =
  if Rails.env.test?
    ActiveSupport::Cache::MemoryStore.new
  else
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      namespace: 'social_auth'
    )
  end
