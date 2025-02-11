# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?

# Load Rails and RSpec Rails – Rails is not loaded until after the environment is set.
require 'rspec/rails'

# -----------------------------------------------------------------------------
# Additional Requires:
#
# Add any additional requires below this line. For example, if you need to load
# custom libraries or support files that are not automatically required.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Require Support Files:
#
# All files in the spec/support directory and its subdirectories (except those
# ending in _spec.rb) are automatically required here. This is useful for custom
# matchers, macros, and shared contexts.
# -----------------------------------------------------------------------------
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# -----------------------------------------------------------------------------
# Check for Pending Migrations:
#
# This will check for any pending migrations before tests are run.
# -----------------------------------------------------------------------------
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Disable ActiveRecord logging during tests for a cleaner test output.
  ActiveRecord::Base.logger = nil if Rails.env.test?

  # -----------------------------------------------------------------------------
  # Shoulda Matchers:
  #
  # If you use shoulda-matchers, you can configure them here. (Make sure you have
  # the shoulda-matchers gem installed and configured in your Gemfile.)
  # -----------------------------------------------------------------------------
  require 'shoulda/matchers'
  Shoulda::Matchers.configure do |matcher_config|
    matcher_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # -----------------------------------------------------------------------------
  # FactoryBot Syntax Methods:
  #
  # This makes methods like create and build available without needing to prefix
  # them with FactoryBot.
  # -----------------------------------------------------------------------------
  config.include FactoryBot::Syntax::Methods

  # -----------------------------------------------------------------------------
  # Load canonical seed data for test environment:
  #
  # This ensures that your canonical CSV data is loaded before your tests run.
  # -----------------------------------------------------------------------------
  config.before(:suite) do
    load Rails.root.join('db', 'seed', 'canonical.rb')
  end

  # -----------------------------------------------------------------------------
  # Backtrace Filtering:
  #
  # Filter out lines from Rails gems in backtraces for clarity.
  # -----------------------------------------------------------------------------
  config.filter_rails_from_backtrace!
  # You can add additional filters here if needed:
  # config.filter_gems_from_backtrace("gem name")
end
