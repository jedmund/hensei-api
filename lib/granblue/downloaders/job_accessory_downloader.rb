# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads job accessory image assets from the game server in different sizes.
    # Job accessories have two types: Shield (type 1) and Manatura (type 2),
    # each served from different CDN paths but stored in unified S3 directories.
    #
    # @example Download images for a specific job accessory
    #   downloader = JobAccessoryDownloader.new("10001", storage: :s3)
    #   downloader.download
    #
    # @note Shield assets live under /shield/, Manatura under /familiar/
    class JobAccessoryDownloader < BaseDownloader
      # Job accessory images come in two sizes: grid and square
      SIZES = %w[grid square].freeze

      SHIELD_BASE_URL = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/shield'
      MANATURA_BASE_URL = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/familiar'

      # Downloads images for a job accessory
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Skips download if accessory is not found in database
      def download(selected_size = nil)
        accessory = JobAccessory.find_by(granblue_id: @id)
        return unless accessory

        @base_url = case accessory.accessory_type
                    when 1 then SHIELD_BASE_URL
                    when 2 then MANATURA_BASE_URL
                    else
                      log_info("Unknown accessory_type #{accessory.accessory_type} for #{@id}")
                      return
                    end

        log_info("-> #{@id}") if @verbose
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES

        sizes.each_with_index do |size, index|
          path = download_path(size)
          url = build_url(size)
          process_download(url, size, path, last: index == sizes.size - 1)
        end
      end

      private

      # Gets object type for file paths and storage keys
      # @return [String] Returns "accessory"
      def object_type
        'accessory'
      end

      # Gets base URL for job accessory assets.
      # This is set dynamically in #download based on accessory_type.
      # @return [String] Base URL for accessory images
      def base_url
        # Default; overridden in #download once accessory_type is known
        SHIELD_BASE_URL
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "grid" -> "m", "square" -> "s"
      def directory_for_size(size)
        case size.to_s
        when 'grid' then 'm'
        when 'square' then 's'
        end
      end
    end
  end
end
