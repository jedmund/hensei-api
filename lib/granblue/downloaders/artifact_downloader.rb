# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads artifact image assets from the game server in different sizes.
    # Artifacts have two sizes: square (s) and wide/medium (m).
    #
    # @example Download images for a specific artifact
    #   downloader = ArtifactDownloader.new("301010101", storage: :both)
    #   downloader.download
    #
    # @note Artifacts don't have variants like characters/weapons - just two sizes
    class ArtifactDownloader < BaseDownloader
      # Artifact images come in two sizes: square and wide
      SIZES = %w[square wide].freeze

      # Downloads images for an artifact
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Skips download if artifact is not found in database
      def download(selected_size = nil)
        artifact = Artifact.find_by(granblue_id: @id)
        return unless artifact

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
      # @return [String] Returns "artifact"
      def object_type
        'artifact'
      end

      # Gets base URL for artifact assets
      # @return [String] Base URL for artifact images
      def base_url
        'https://prd-game-a1-granbluefantasy.akamaized.net/assets_en/img/sp/assets/artifact'
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "square" -> "s", "wide" -> "m"
      def directory_for_size(size)
        case size.to_s
        when 'square' then 's'
        when 'wide' then 'm'
        end
      end

      # Build complete URL for a size variant
      # @param size [String] Image size variant
      # @return [String] Complete download URL
      def build_url(size)
        directory = directory_for_size(size)
        "#{base_url}/#{directory}/#{@id}.jpg"
      end
    end
  end
end
