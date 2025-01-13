# frozen_string_literal: true

require_relative '../logging_helper'

class PostDeploymentManager
  include LoggingHelper

  STORAGE_DESCRIPTIONS = {
    local: 'to local disk',
    s3: 'to S3',
    both: 'to local disk and S3'
  }.freeze

  def initialize(options = {})
    @test_mode = options.fetch(:test_mode, false)
    @verbose = options.fetch(:verbose, false)
    @storage = options.fetch(:storage, :both)
    @new_records = Hash.new { |h, k| h[k] = [] }
    @updated_records = Hash.new { |h, k| h[k] = [] }
  end

  def run
    migrate_database
    import_new_data
    display_import_summary
    download_images
    rebuild_search_indices
    display_completion_message
  end

  private

  def migrate_database
    log_header 'Running database migrations...', '-'
    puts "\n"
    if @test_mode
      log_step "TEST MODE: Would run pending migrations..."
    else
      ActiveRecord::Migration.verbose = @verbose
      version = ActiveRecord::Migrator.current_version
      ActiveRecord::Tasks::DatabaseTasks.migrate
      new_version = ActiveRecord::Migrator.current_version
      if version == new_version
        log_step "No pending migrations."
      else
        log_step "Migrated from version #{version} to #{new_version}"
      end
    end
  end

  def import_new_data
    log_header 'Importing new data...'
    puts "\n"
    importer = Granblue::DataImporter.new(
      test_mode: @test_mode,
      verbose: @verbose
    )

    process_imports(importer)
  end

  def process_imports(importer)
    importer.process_all_files do |result|
      result[:new].each do |type, ids|
        @new_records[type].concat(ids)
      end
      result[:updated].each do |type, ids|
        @updated_records[type].concat(ids)
      end
    end
  end

  def rebuild_search_indices
    log_header 'Rebuilding search indices...', '-'
    puts "\n"
    [Character, Summon, Weapon, Job].each do |model|
      log_verbose "• #{model.name}... "
      PgSearch::Multisearch.rebuild(model)
      log_verbose "✅ done!\n"
    end
  end

  def display_import_summary
    if @new_records.size > 0 || @updated_records.size > 0
      log_header 'Import Summary', '-'
      puts "\n"
      display_record_summary('New', @new_records)
      display_record_summary('Updated', @updated_records)
    else
      log_step "\nNo new records imported."
    end
  end

  def display_record_summary(label, records)
    records.each do |type, ids|
      next if ids.empty?
      puts "#{type.capitalize}: #{ids.size} #{label.downcase} records"
      puts "IDs: #{ids.inspect}" if @verbose
    end
  end

  def download_images
    return if all_records_empty?

    if @test_mode
      log_step "\nTEST MODE: Would download images for new and updated records..."
    else
      log_header 'Downloading images...', '+'
    end

    [@new_records, @updated_records].each do |records|
      records.each do |type, ids|
        next if ids.empty?
        download_type_images(type, ids)
      end
    end
  end

  def download_type_images(type, ids)
    log_step "\nProcessing new #{type.pluralize} (#{ids.size} records)..."
    download_options = {
      test_mode: @test_mode,
      verbose: @verbose,
      storage: @storage
    }

    ids.each do |id|
      download_single_image(type, id, download_options)
    end
  end

  def download_single_image(type, id, options)
    action_text = @test_mode ? 'Would download' : 'Downloading'
    storage_text = STORAGE_DESCRIPTIONS[options[:storage]]
    log_verbose "\n#{action_text} images #{storage_text} for #{type} #{id}...\n"

    Granblue::Downloader::DownloadManager.download_for_object(
      type,
      id,
      **options
    )
  rescue => e
    error_message = "Error #{@test_mode ? 'would occur' : 'occurred'} downloading images for #{type} #{id}: #{e.message}"
    puts error_message
    puts e.backtrace.take(5) if @verbose
  end

  def display_completion_message
    if @test_mode
      log_step "\n✓ Test run completed successfully!"
    else
      log_step "\n✓ Post-deployment tasks completed successfully!"
    end
  end

  def all_records_empty?
    @new_records.values.all?(&:empty?) && @updated_records.values.all?(&:empty?)
  end
end
