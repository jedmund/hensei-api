# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads weapon image assets from the game server in different sizes and variants.
    # Handles weapon-specific variants like base art, transcendence art, and elemental variants.
    #
    # @example Download images for a specific weapon
    #   downloader = WeaponDownloader.new("1040001000", storage: :both)
    #   downloader.download
    #
    # @note Weapon images come in multiple variants based on uncap and element status
    # @note Supports transcendence variants and element-specific variants
    # @see ElementalWeaponDownloader for handling multi-element weapons
    class WeaponDownloader < BaseDownloader
      # Override SIZES to include 'base' for b directory images
      SIZES = %w[main grid square base].freeze

      # Maps internal element ID to game source offset
      # :note means use _note suffix on base ID, integer means add offset to base ID
      # Internal: 0=Null, 1=Wind, 2=Fire, 3=Water, 4=Earth, 5=Dark, 6=Light
      # Game order: Fire (base), Water (+100), Earth (+200), Wind (+300), Light (+400), Dark (+500)
      ELEMENT_SOURCE_MAP = {
        0 => :note,  # {id}_note -> {id}_0 (Null/no element)
        1 => 300,    # {id+300} -> {id}_1 (Wind)
        2 => 0,      # {id}     -> {id}_2 (Fire)
        3 => 100,    # {id+100} -> {id}_3 (Water)
        4 => 200,    # {id+200} -> {id}_4 (Earth)
        5 => 500,    # {id+500} -> {id}_5 (Dark)
        6 => 400     # {id+400} -> {id}_6 (Light)
      }.freeze
      # Downloads images for all variants of a weapon based on their uncap status.
      # Overrides {BaseDownloader#download} to handle weapon-specific variants.
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Skips download if weapon is not found in database
      # @note Downloads transcendence variants only if weapon has those uncaps
      # @see #download_variants
      def download(selected_size = nil)
        weapon = Weapon.find_by(granblue_id: @id)
        unless weapon
          log_info "Weapon #{@id} not found in database, skipping"
          return
        end

        log_info "Downloading weapon #{@id} (#{weapon.name_en}), selected_size=#{selected_size || 'all'}"
        download_variants(weapon, selected_size)
      end

      private

      # Downloads all variants of a weapon's images
      #
      # @param weapon [Weapon] Weapon model instance to download images for
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Only downloads variants that should exist based on weapon uncap status
      # @note Handles special transcendence art variants for transcendable weapons
      # @note Downloads element variants for element-changeable weapons
      def download_variants(weapon, selected_size = nil)
        # All weapons have base variant
        variants = [@id]

        # Add transcendence variants if available
        variants.push("#{@id}_02", "#{@id}_03") if weapon.transcendence

        log_info "Downloading weapon variants: #{variants.join(', ')}" if @verbose

        variants.each do |variant_id|
          download_variant(variant_id, selected_size)
        end

        # Download element variants for element-changeable weapons (which are null element)
        download_element_variants(weapon, selected_size) if Weapon.element_changeable?(weapon)
      end

      # Downloads a specific variant's images in all sizes
      #
      # @param variant_id [String] Weapon variant ID (e.g., "1040001000_02")
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Downloads all size variants (main/grid/square) for the given variant
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

      # Downloads all element variants for element-changeable weapons.
      # Uses variant IDs from the weapon record when available, falling back to offset math.
      #
      # @param weapon [Weapon] Weapon model instance
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_element_variants(weapon, selected_size = nil)
        base_id = @id.to_i
        variant_ids = weapon.element_variant_ids || {}
        log_info "Downloading element variants for #{@id} (base_id=#{base_id}, variant_ids=#{variant_ids})"

        ELEMENT_SOURCE_MAP.each do |element_id, source|
          variant_id = variant_ids[element_id.to_s]

          if variant_id
            source_id = variant_id
            target_stem = variant_id
          elsif source == :note
            source_id = "#{base_id}_note"
            target_stem = "#{@id}_#{element_id}"
          else
            source_id = (base_id + source).to_s
            target_stem = "#{@id}_#{element_id}"
          end

          log_info "  Element #{element_id}: source=#{source_id} -> target=#{target_stem}"
          download_element_variant(source_id, target_stem, selected_size)
        end
      end

      # Downloads a single element variant in all sizes
      #
      # @param source_id [String] Source ID to download from (e.g., "1040007900" or "1040001100")
      # @param target_stem [String] Filename stem for storage (e.g., "1040007900" or "1040002000_1")
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_element_variant(source_id, target_stem, selected_size = nil)
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES

        sizes.each do |size|
          path = download_path(size)
          source_url = build_variant_url(source_id, size)
          target_filename = "#{target_stem}.#{size == 'base' ? 'png' : 'jpg'}"

          process_element_download(source_url, size, path, target_filename)
        end
      end

      # Process download for element variant (source URL differs from target filename)
      #
      # @param url [String] Source URL to download from
      # @param size [String] Image size variant
      # @param path [String] Local directory path
      # @param filename [String] Target filename to save as
      # @return [void]
      def process_element_download(url, size, path, filename)
        s3_key = build_s3_key(size, filename)
        local_path = "#{path}/#{filename}"

        unless should_download?(local_path, s3_key)
          log_info "\t  #{size}: skipped (already exists, force=#{@force})"
          return
        end

        log_info "\t├ #{size}: #{url} -> #{filename} (s3_key=#{s3_key})"

        case @storage
        when :local
          download_element_to_local(url, local_path)
        when :s3
          stream_element_to_s3(url, s3_key)
        when :both
          download_element_to_both(url, local_path, s3_key)
        end
        log_info "\t  #{size}: done"
      rescue OpenURI::HTTPError => e
        log_info "\t  #{size}: HTTP error #{e.message} for #{url}"
      rescue StandardError => e
        log_info "\t  #{size}: ERROR #{e.class} - #{e.message} for #{url}"
      end

      # Download element variant to local storage
      def download_element_to_local(url, local_path)
        URI.parse(url).open do |file|
          IO.copy_stream(file, local_path)
        end
      end

      # Stream element variant to S3
      def stream_element_to_s3(url, s3_key)
        if !@force && @aws_service&.file_exists?(s3_key)
          log_info "\t  s3: skipped #{s3_key} (exists, force=#{@force})"
          return
        end

        URI.parse(url).open do |file|
          @aws_service.upload_stream(file, s3_key)
        end
      end

      # Download element variant to both local and S3
      def download_element_to_both(url, local_path, s3_key)
        download = URI.parse(url).open

        # Write to local file
        IO.copy_stream(download, local_path)

        # Reset file pointer for S3 upload
        download.rewind

        # Upload to S3 if force or if it doesn't exist
        return if !@force && @aws_service&.file_exists?(s3_key)

        @aws_service.upload_stream(download, s3_key)
      end

      # Builds URL for a specific variant and size
      #
      # @param variant_id [String] Weapon variant ID
      # @param size [String] Image size variant ("main", "grid", "square", or "base")
      # @return [String] Complete URL for downloading the image
      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)
        if size == 'base'
          "#{@base_url}/#{directory}/#{variant_id}.png"
        else
          "#{@base_url}/#{directory}/#{variant_id}.jpg"
        end
      end

      # Gets object type for file paths and storage keys
      # @return [String] Returns "weapon"
      def object_type
        'weapon'
      end

      # Gets base URL for weapon assets
      # @return [String] Base URL for weapon images
      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/weapon'
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "main" -> "ls", "grid" -> "m", "square" -> "s", "base" -> "b"
      def directory_for_size(size)
        case size.to_s
        when 'main' then 'ls'
        when 'grid' then 'm'
        when 'square' then 's'
        when 'base' then 'b'
        end
      end
    end
  end
end
