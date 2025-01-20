require_relative "boot"

require "rails"

# Include only the Rails frameworks we need
require "active_model/railtie" # Basic model functionality
require "active_job/railtie" # Background job processing
require "active_record/railtie" # Database support
require "active_storage/engine" # File upload and storage
require "action_controller/railtie" # API controller support
require "action_text/engine" # Rich text handling
require "action_view/railtie" # View rendering (needed for some API responses)
require "rails/test_unit/railtie" # Testing framework

# Load gems from Gemfile
Bundler.require(*Rails.groups)

module HenseiApi
  class Application < Rails::Application
    # Use Rails 7.0 defaults
    config.load_defaults 7.0

    # Configure autoloading
    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")

    # Configure asset handling for API mode
    config.paths["app/assets"] ||= []
    config.paths["app/assets"].unshift(Rails.root.join("app", "assets").to_s)
    config.assets.paths << Rails.root.join("app", "assets", "fonts")

    # API-only application configuration
    config.api_only = true
  end
end
