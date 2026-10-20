# frozen_string_literal: true

namespace :collection_artifacts do
  desc 'Set collection_artifacts.raw_data to NULL in batches (BATCH_SIZE, default 5000). Safe to re-run.'
  task clear_raw_data: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', CollectionArtifacts::RawDataClearer::BATCH_SIZE)
    cleared = CollectionArtifacts::RawDataClearer.new(batch_size: batch_size).call do |batch, total|
      puts "batch #{batch}: #{total} cleared so far" if (batch % 20).zero?
    end
    puts "collection_artifacts.raw_data: #{cleared} rows cleared"
  end
end
