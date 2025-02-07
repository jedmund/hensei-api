redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.death_handlers << ->(job, ex) do
    Rails.logger.error("Preview generation job #{job['jid']} failed with: #{ex.message}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
