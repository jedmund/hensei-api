# frozen_string_literal: true

require_relative '../post_deployment/manager'
require_relative '../logging_helper'

namespace :deploy do
  desc 'Post-deployment tasks: Run migrations, import data, download images, and rebuild search indices. Options: TEST=true for test mode, VERBOSE=true for verbose output, STORAGE=local|s3|both'
  task post_deployment: :environment do
    include LoggingHelper

    # Load all required files
    Dir[Rails.root.join('lib', 'post_deployment', '**', '*.rb')].each { |file| require file }
    Dir[Rails.root.join('lib', 'granblue', '**', '*.rb')].each { |file| require file }

    # Ensure Rails environment is loaded
    Rails.application.eager_load!

    begin
      display_startup_banner

      options = parse_and_validate_options
      display_configuration(options)

      # Execute the deployment tasks
      manager = PostDeployment::Manager.new(options)
      manager.run

    rescue StandardError => e
      display_error(e)
      exit 1
    end
  end

  private

  def display_startup_banner
    puts "Starting deployment process...\n"
  end

  def parse_and_validate_options
    storage = parse_storage_option

    {
      test_mode: ENV['TEST'] == 'true',
      verbose: ENV['VERBOSE'] == 'true',
      storage: storage,
      force: ENV['FORCE'] == 'true'
    }
  end

  def parse_storage_option
    storage = (ENV['STORAGE'] || 'both').to_sym

    unless [:local, :s3, :both].include?(storage)
      raise ArgumentError, 'Invalid STORAGE option. Must be one of: local, s3, both'
    end

    storage
  end

  def display_configuration(options)
    log_header('Configuration', '-')
    puts "\n"
    display_status("Test mode", options[:test_mode])
    display_status("Verbose output", options[:verbose])
    display_status("Process all", options[:force])
    puts "Storage mode:\t#{options[:storage]}"
    puts "\n"
  end

  def display_status(label, enabled)
    status = enabled ? "✅ Enabled" : "❌ Disabled"
    puts "#{label}:\t#{status}"
  end

  def display_error(error)
    puts "\n❌ Error during deployment:"
    puts "  #{error.class}: #{error.message}"
    puts "\nStack trace:" if ENV['VERBOSE'] == 'true'
    puts error.backtrace.take(10) if ENV['VERBOSE'] == 'true'
    puts "\nDeployment failed! Please check the logs for details."
  end
end
