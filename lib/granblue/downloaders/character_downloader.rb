# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads character image assets from the game server in different sizes and variants.
    # Handles character-specific variants like base art, uncap art, and transcendence art.
    #
    # @example Download images for a specific character
    #   downloader = CharacterDownloader.new("3040001000", storage: :both)
    #   downloader.download
    #
    # @note Character images come in multiple variants (_01, _02, etc.) based on uncap status
    # @note Supports FLB (5★) and ULB (6★) art variants when available
    class CharacterDownloader < BaseDownloader
      # Downloads images for all variants of a character based on their uncap status.
      # Overrides {BaseDownloader#download} to handle character-specific variants.
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Skips download if character is not found in database
      # @note Downloads FLB/ULB variants only if character has those uncaps
      # @see #download_variants
      def download(selected_size = nil)
        character = Character.find_by(granblue_id: @id)
        return unless character

        download_variants(character, selected_size)
      end

      private

      # Downloads all variants of a character's images
      #
      # @param character [Character] Character model instance to download images for
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Only downloads variants that should exist based on character uncap status
      def download_variants(character, selected_size = nil)
        # All characters have 01 and 02 variants
        variants = %W[#{@id}_01 #{@id}_02]

        # Add FLB variant if available
        variants << "#{@id}_03" if character.flb

        # Add ULB variant if available
        variants << "#{@id}_04" if character.ulb

        log_info "Downloading character variants: #{variants.join(', ')}" if @verbose

        variants.each do |variant_id|
          download_variant(variant_id, selected_size)
        end
      end

      # Downloads a specific variant's images in all sizes
      #
      # @param variant_id [String] Character variant ID (e.g., "3040001000_01")
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_variant(variant_id, selected_size = nil)
        log_info "-> #{variant_id}" if @verbose
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES

        sizes.each_with_index do |size, index|
          path = download_path(size)
          url = build_variant_url(variant_id, size)
          process_download(url, size, path, last: index == SIZES.size - 1)
        end
      end

      # Builds URL for a specific variant and size
      #
      # @param variant_id [String] Character variant ID
      # @param size [String] Image size variant ("main", "grid", "square", or "detail")
      # @return [String] Complete URL for downloading the image
      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)
        "#{@base_url}/#{directory}/#{variant_id}.jpg"
      end

      # Gets object type for file paths and storage keys
      # @return [String] Returns "character"
      def object_type
        'character'
      end

      # Gets base URL for character assets
      # @return [String] Base URL for character images
      def base_url
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/npc'
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "main" -> "f", "grid" -> "m", "square" -> "s"
      def directory_for_size(size)
        case size.to_s
        when 'main' then 'f'
        when 'grid' then 'm'
        when 'square' then 's'
        end
      end
    end
  end
end
