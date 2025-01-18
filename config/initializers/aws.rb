Rails.application.config.after_initialize do
  Rails.logger.info "Initializing AWS Service..."
  begin
    AwsService.new
    Rails.logger.info "AWS Service initialized successfully"
  rescue => e
    Rails.logger.error "Failed to initialize AWS Service: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
