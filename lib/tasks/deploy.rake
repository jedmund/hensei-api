# frozen_string_literal: true

require_relative '../granblue/downloaders/base_downloader'
require_relative '../logging_helper'

namespace :deploy do
  desc 'Post-deployment tasks: Import new data and download related images. Options: TEST=true for test mode, VERBOSE=true for verbose output, STORAGE=local|s3|both'
  task post_deployment: :environment do
    include LoggingHelper

    Dir[Rails.root.join('lib', 'granblue', '**', '*.rb')].each { |file| require file }

    # Ensure Rails environment is loaded
    Rails.application.eager_load!

    log_header('Starting post-deploy script...', '*', false)
    print "\n"

    # Parse and validate storage option
    storage = (ENV['STORAGE'] || 'both').to_sym
    unless [:local, :s3, :both].include?(storage)
      puts 'Invalid STORAGE option. Must be one of: local, s3, both'
      exit 1
    end

    options = {
      test_mode: ENV['TEST'] == 'true',
      verbose: ENV['VERBOSE'] == 'true',
      storage: storage
    }

    print "Test mode:\t"
    if options[:test_mode]
      print "✅ Enabled\n"
    else
      print "❌ Disabled\n"
    end

    print "Verbose output:\t"
    if options[:verbose]
      print "✅ Enabled\n"
    else
      print "❌ Disabled\n"
    end

    puts "Storage mode:\t#{storage}"

    # Execute the task
    manager = PostDeploymentManager.new(options)
    manager.run
  end
end
