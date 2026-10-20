# frozen_string_literal: true

module CharacterSkills
  # Where the editor refresh keeps its previews (PR 5): the fetched wikitext under a preview
  # token for 30 minutes, and a batch refresh's state and texts for 24 hours.
  #
  # Not Rails.cache: production doesn't configure one (the default is a file store per
  # container), and the batch is written by the API and read by the Sidekiq service, so it
  # has to be shared. Redis, like the rate limit store; an in-memory store in tests
  # (specs call .clear).
  module RefreshStore
    PREVIEW_TTL = 30.minutes
    BATCH_TTL = 24.hours

    module_function

    def store
      @store ||= if Rails.env.test?
                   ActiveSupport::Cache::MemoryStore.new
                 else
                   ActiveSupport::Cache::RedisCacheStore.new(
                     url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
                     namespace: 'character_skill_refresh'
                   )
                 end
    end

    def read(key) = store.read(key)
    def write(key, value, expires_in:) = store.write(key, value, expires_in: expires_in)
    def delete(key) = store.delete(key)
    def clear = store.clear
  end
end
