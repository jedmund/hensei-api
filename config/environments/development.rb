require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  config.hosts << 'staging-api.granblue.team'

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true
  #

  logger = ActiveSupport::Logger.new(STDOUT)
  # To support a formatter, you must manually assign a formatter from the config.log_formatter value to the logger.
  logger.formatter = config.log_formatter
  # config.logger is the logger that will be used for Rails.logger and any
  # related Rails logging such as ActiveRecord::Base.logger.
  # It defaults to an instance of ActiveSupport::TaggedLogging that wraps an
  # instance of ActiveSupport::Logger which outputs a log to the log/ directory.
  config.logger = ActiveSupport::TaggedLogging.new(logger)
  # config.log_level defines the verbosity of the Rails logger.
  # This option defaults to :debug for all environments.
  # The available log levels are: :debug, :info, :warn, :error, :fatal, and :unknown
  # config.log_level = :debug
  # config.log_tags accepts a list of: methods that the request object responds to,
  # a Proc that accepts the request object, or something that responds to to_s.
  # This makes it easy to tag log lines with debug information like subdomain and request id -
  # both very helpful in debugging multi-user production applications.
  config.log_tags = [:request_id]
end
