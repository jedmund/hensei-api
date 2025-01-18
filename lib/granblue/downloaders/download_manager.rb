# frozen_string_literal: true

module Granblue
  module Downloaders
    # Manages downloading of game assets by coordinating different downloader types.
    # Provides a single interface for downloading any type of game asset.
    #
    # @example Download character images
    #   DownloadManager.download_for_object('character', '3040001000', storage: :s3)
    #
    # @example Download weapon images in test mode
    #   DownloadManager.download_for_object('weapon', '1040001000', test_mode: true, verbose: true)
    #
    # @note Automatically selects the appropriate downloader based on object type
    # @note Handles configuration of downloader options consistently across types
    class DownloadManager
      class << self
        # Downloads assets for a specific game object using the appropriate downloader
        #
        # @param type [String] Type of game object ('character', 'weapon', or 'summon')
        # @param granblue_id [String] Game ID of the object to download assets for
        # @param test_mode [Boolean] When true, simulates downloads without actually downloading
        # @param verbose [Boolean] When true, enables detailed logging
        # @param storage [Symbol] Storage mode to use (:local, :s3, or :both)
        # @return [void]
        #
        # @example Download character images to S3
        #   DownloadManager.download_for_object('character', '3040001000', storage: :s3)
        #
        # @example Test weapon downloads with verbose logging
        #   DownloadManager.download_for_object('weapon', '1040001000',
        #     test_mode: true,
        #     verbose: true
        #   )
        #
        # @note Logs warning if object type is unknown
        # @see CharacterDownloader
        # @see WeaponDownloader
        # @see SummonDownloader
        def download_for_object(type, granblue_id, test_mode: false, verbose: false, storage: :both)
          downloader_options = {
            test_mode: test_mode,
            verbose: verbose,
            storage: storage
          }

          case type
          when 'character'
            CharacterDownloader.new(granblue_id, **downloader_options).download
          when 'weapon'
            WeaponDownloader.new(granblue_id, **downloader_options).download
          when 'summon'
            SummonDownloader.new(granblue_id, **downloader_options).download
          else
            log_info "Unknown object type: #{type}" if verbose || test_mode
          end
        end
      end
    end
  end
end
