# frozen_string_literal: true

# A counter in Redis that a cache puts in its key (or compares against its
# memo), so bumping it clears that cache in every process: the web
# containers and Sidekiq each have their own Rails.cache and memory. Both
# calls are best-effort; while Redis is unreachable, `current` is nil and
# caches fall back to their own expiry.
module CacheEpoch
  PREFIX = 'cache_epoch'

  module_function

  def current(name)
    Sidekiq.redis { |redis| redis.get("#{PREFIX}:#{name}") }.to_i
  rescue StandardError => e
    Rails.logger.warn("cache epoch #{name} unavailable: #{e.class}")
    nil
  end

  def bump(name)
    Sidekiq.redis { |redis| redis.incr("#{PREFIX}:#{name}") }
  rescue StandardError => e
    Rails.logger.warn("cache epoch #{name} not bumped: #{e.class}")
    nil
  end
end
