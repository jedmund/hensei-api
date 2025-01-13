namespace :deploy do
  desc 'Post-deployment tasks: Import new data and download related images. Options: TEST=true for test mode, VERBOSE=true for verbose output, STORAGE=local|s3|both'
  task post_deployment: :environment do
    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', '**', '*.rb')].each { |file| require file }

    # Ensure Rails environment is loaded
    Rails.application.eager_load!
    
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

    if options[:test_mode]
      puts 'Test mode enabled'
    end

    if options[:verbose]
      puts 'Verbose output enabled'
    end

    puts "Storage mode: #{storage}"

    # Execute the task
    manager = PostDeploymentManager.new(options)
    manager.run
  end
end
