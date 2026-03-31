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
      # Override SIZES to include 'detail' for detail images
      SIZES = %w[main grid square detail].freeze
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
        if character.style_swap?
          # Style swap characters only have a single style variant
          log_info "Downloading style swap variant: #{@id}_01_st2 -> #{@id}_01_style" if @verbose
          download_style_variant(selected_size)
        else
          # All characters have 01 and 02 variants
          poses = %w[01 02]
          poses << '03' if character.flb
          poses << '04' if character.transcendence

          variants = poses.map { |pose| "#{@id}_#{pose}" }

          log_info "Downloading character variants: #{variants.join(', ')}" if @verbose

          variants.each do |variant_id|
            download_variant(variant_id, selected_size)
          end

          # Null-element characters (element == 0) have element-suffixed variants
          download_element_variants(poses, selected_size) if character.element&.zero?
        end
      end

      # Downloads element-suffixed variants for null-element characters.
      # For each pose, element (1-6), and gender (0=Gran, 1=Djeeta),
      # downloads {id}_{pose}_0{element}_{gender} in all sizes.
      # Not all characters have both gender variants; missing ones fail silently.
      #
      # @param poses [Array<String>] Available poses (e.g., ["01", "02", "03"])
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_element_variants(poses, selected_size = nil)
        log_info "Downloading element variants for null-element character #{@id}"

        (1..6).each do |element|
          poses.each do |pose|
            (0..1).each do |gender|
              variant_id = "#{@id}_#{pose}_0#{element}_#{gender}"
              download_variant(variant_id, selected_size)
            end
          end
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
          process_download(url, size, path, last: index == sizes.size - 1)
        end
      end

      # Downloads style swap images, fetching from _st2 URLs and storing with _style suffix
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_style_variant(selected_size = nil)
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES
        source_id = "#{@id}_01_st2"
        storage_id = "#{@id}_01_style"

        sizes.each_with_index do |size, index|
          source_url = build_variant_url(source_id, size)
          ext = size == 'detail' ? '.png' : '.jpg'
          storage_filename = "#{storage_id}#{ext}"
          path = download_path(size)
          s3_key = build_s3_key(size, storage_filename)
          local_path = "#{path}/#{storage_filename}"

          next unless should_download?(local_path, s3_key)

          if index == sizes.size - 1
            log_info "\t└ #{size}: #{source_url} -> #{storage_filename}..."
          else
            log_info "\t├ #{size}: #{source_url} -> #{storage_filename}..."
          end

          case @storage
          when :local
            download_to_local(source_url, local_path)
          when :s3
            stream_to_s3(source_url, s3_key)
          when :both
            download_to_both(source_url, local_path, s3_key)
          end
        rescue OpenURI::HTTPError
          log_info "\t404 returned\t#{source_url}"
        end
      end

      # Builds URL for a specific variant and size
      #
      # @param variant_id [String] Character variant ID
      # @param size [String] Image size variant ("main", "grid", "square", or "detail")
      # @return [String] Complete URL for downloading the image
      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)

        if size == 'detail'
          "#{@base_url}/#{directory}/#{variant_id}.png"
        else
          "#{@base_url}/#{directory}/#{variant_id}.jpg"
        end
      end

      # Gets object type for file paths and storage keys
      # @return [String] Returns "character"
      def object_type
        'character'
      end

      # Gets base URL for character assets
      # @return [String] Base URL for character images
      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/npc'
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
        when 'detail' then 'detail'
        end
      end
    end
  end
end
