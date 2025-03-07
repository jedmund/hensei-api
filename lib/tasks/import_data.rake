# frozen_string_literal: true

namespace :granblue do
  desc "Import weapon, summon and character data from db/seed/updates. Use TEST=true for test mode."
  task import_data: :environment do
    require 'csv'
    Dir[Rails.root.join('lib', 'granblue', '**', '*.rb')].each { |file| require file }

    test_mode = ENV['TEST'] == 'true'
    verbose = ENV['VERBOSE'] == 'true'
    importer = PostDeployment::DataImporter.new(test_mode: test_mode, verbose: verbose)
    importer.process_all_files
  end
end
