# frozen_string_literal: true

require_relative '../logging_helper'
require_relative '../granblue/downloaders/base_downloader'
require_relative '../granblue/downloaders/character_downloader'
require_relative '../granblue/downloaders/weapon_downloader'
require_relative '../granblue/downloaders/summon_downloader'
require_relative '../granblue/downloaders/elemental_weapon_downloader'
require_relative '../granblue/downloaders/download_manager'

module PostDeployment
  class ImageDownloader
    include LoggingHelper

    STORAGE_DESCRIPTIONS = {
      local: 'to local disk',
      s3: 'to S3',
      both: 'to local disk and S3'
    }.freeze

    SUPPORTED_TYPES = {
      'character' => Granblue::Downloaders::CharacterDownloader,
      'summon' => Granblue::Downloaders::SummonDownloader,
      'weapon' => Granblue::Downloaders::WeaponDownloader
    }.freeze

    def initialize(test_mode:, verbose:, storage:, new_records:, updated_records:)
      @test_mode = test_mode
      @verbose = verbose
      @storage = storage
      @new_records = new_records
      @updated_records = updated_records
    end

    def run
      return if @test_mode

      log_header 'Downloading images...', '+'

      SUPPORTED_TYPES.each do |type, downloader_class|
        download_type_images(type, downloader_class)
      end
    end

    private

    def download_type_images(type, downloader_class)
      records = (@new_records[type] || []) + (@updated_records[type] || [])
      return if records.empty?

      puts "\nDownloading #{type} images..." if @verbose
      records.each do |record|
        # Get the ID either from the granblue_id hash key (test mode) or method (normal mode)
        id = record.respond_to?(:granblue_id) ? record.granblue_id : record[:granblue_id]

        downloader = downloader_class.new(
          id,
          test_mode: @test_mode,
          verbose: @verbose,
          storage: @storage
        )
        downloader.download
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
