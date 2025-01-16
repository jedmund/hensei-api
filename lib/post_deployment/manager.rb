# frozen_string_literal: true

require_relative 'test_mode_transaction'
require_relative 'database_migrator'
require_relative 'data_importer'
require_relative 'image_downloader'
require_relative 'search_indexer'
require_relative '../logging_helper'

module PostDeployment
  class Manager
    include LoggingHelper

    def initialize(options = {})
      @test_mode = options.fetch(:test_mode, false)
      @verbose = options.fetch(:verbose, false)
      @storage = options.fetch(:storage, :both)
      @force = options.fetch(:force, false)
      @new_records = Hash.new { |h, k| h[k] = [] }
      @updated_records = Hash.new { |h, k| h[k] = [] }
      @test_transaction = TestModeTransaction.new if @test_mode
    end

    def run
      migrate_database
      import_new_data
      display_import_summary
      download_images
      rebuild_search_indices
      display_completion_message
    rescue => e
      handle_error(e)
    end

    private

    def migrate_database
      DatabaseMigrator.new(
        test_mode: @test_mode,
        verbose: @verbose
      ).run
    end

    def import_new_data
      log_header 'Importing new data...'
      puts "\n"

      importer = DataImporter.new(
        test_mode: @test_mode,
        verbose: @verbose,
        test_transaction: @test_transaction,
        force: @force
      )

      process_imports(importer)
    end

    def process_imports(importer)
      importer.process_all_files do |result|
        merge_import_results(result)
      end
    end

    def merge_import_results(result)
      result[:new].each do |type, records|
        @new_records[type].concat(records)
      end
      result[:updated].each do |type, records|
        @updated_records[type].concat(records)
      end
    end

    def download_images
      return if all_records_empty?

      ImageDownloader.new(
        test_mode: @test_mode,
        verbose: @verbose,
        storage: @storage,
        new_records: @new_records,
        updated_records: @updated_records
      ).run
    end

    def rebuild_search_indices
      SearchIndexer.new(
        test_mode: @test_mode,
        verbose: @verbose
      ).rebuild_all
    end

    def display_import_summary
      if @new_records.size > 0 || @updated_records.size > 0
        log_header 'Import Summary', '-'
        display_record_summary('New', @new_records)
        display_record_summary('Updated', @updated_records)
      else
        log_step "\nNo new records imported."
      end
    end

    def display_record_summary(label, records)
      records.each do |type, items|
        next if items.empty?
        count = items.size
        puts "\n#{type.capitalize}: #{count} #{label.downcase} #{count == 1 ? 'record' : 'records'}"
        items.each do |item|
          puts "  - #{item[:name_en]} (ID: #{item[:granblue_id]})"
        end
      end
    end

    def display_completion_message
      if @test_mode
        log_header "✅ Test run completed successfully!", "-"
        puts "\n"
        log_step "#{@new_records.values.flatten.size} records would be created"
        log_step "#{@updated_records.values.flatten.size} records would be updated"
        puts "\n"
      else
        log_header "✅ Post-deployment tasks completed successfully!"
      end
    end

    def handle_error(error)
      error_message = format_error_message(error)
      log_formatted_error(error_message)
      @test_transaction&.rollback
      exit(1)
    end

    def format_error_message(error)
      sections = []

      # Add header section
      sections << [
        "═" * 60,
        "❌ Error during deployment",
        "═" * 60
      ]

      # Add main error message
      sections << format_main_error(error)

      # Add stack trace if verbose
      if @verbose && error.respond_to?(:backtrace)
        sections << [
          "Stack trace:",
          error.backtrace.take(5).map { |line| "  #{line}" }
        ].flatten
      end

      sections.flatten.join("\n")
    end

    def format_main_error(error)
      case error
      when Granblue::Importers::ImportError
        [
          "File: #{error.file_name}",
          "-" * 80,
          error.details
        ]
      else
        error.message.to_s
      end
    end

    def log_formatted_error(message)
      # Split message into lines and log each with error prefix
      message.split("\n").each do |line|
        log_error line
      end
    end

    def all_records_empty?
      @new_records.values.all?(&:empty?) && @updated_records.values.all?(&:empty?)
    end
  end
end
