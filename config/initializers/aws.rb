Rails.application.config.after_initialize do
  next if defined?(Rake) && Rake.application.top_level_tasks.any?

  Rails.logger.info "Initializing AWS Service..."
  begin
    AwsService.new
    Rails.logger.info "AWS Service initialized successfully"
  rescue StandardError => e
    Rails.logger.warn "Skipping AWS Service: #{e.message}"
  end
end
