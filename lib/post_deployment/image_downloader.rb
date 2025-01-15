# frozen_string_literal: true

require_relative '../logging_helper'

module PostDeployment
  class ImageDownloader
    include LoggingHelper

    STORAGE_DESCRIPTIONS = {
      local: 'to local disk',
      s3: 'to S3',
      both: 'to local disk and S3'
    }.freeze

    def initialize(test_mode:, verbose:, storage:, new_records:, updated_records:)
      @test_mode = test_mode
      @verbose = verbose
      @storage = storage
      @new_records = new_records
      @updated_records = updated_records
    end

    def run
      log_header 'Downloading images...', '+'

      [@new_records, @updated_records].each do |records|
        records.each do |type, items|
          next if items.empty?
          download_type_images(type, items)
        end
      end
    end

    private

    def download_type_images(type, items)
      if @verbose
        log_header "Processing #{type.pluralize} (#{items.size} records)...", "-"
        puts "\n"
      end

      download_options = {
        test_mode: @test_mode,
        verbose: @verbose,
        storage: @storage
      }

      items.each do |item|
        id = @test_mode ? item[:granblue_id] : item.id
        download_single_image(type, id, download_options)
      end

    end

    def download_single_image(type, id, options)
      action_text = @test_mode ? 'Would download' : 'Downloading'
      storage_text = STORAGE_DESCRIPTIONS[options[:storage]]
      log_verbose "#{action_text} images #{storage_text} for #{type} #{id}...\n"

      unless @test_mode
        Granblue::Downloader::DownloadManager.download_for_object(
          type,
          id,
          **options
        )
      end
    rescue => e
      error_message = "Error #{@test_mode ? 'would occur' : 'occurred'} downloading images for #{type} #{id}: #{e.message}"
      puts error_message
      puts e.backtrace.take(5) if @verbose
    end
  end
end
