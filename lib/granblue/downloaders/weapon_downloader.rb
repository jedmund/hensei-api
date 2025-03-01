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
        return unless weapon

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
      def download_variants(weapon, selected_size = nil)
        # All weapons have base variant
        variants = [@id]

        # Add transcendence variants if available
        variants.push("#{@id}_02", "#{@id}_03") if weapon.transcendence

        log_info "Downloading weapon variants: #{variants.join(', ')}" if @verbose

        variants.each do |variant_id|
          download_variant(variant_id, selected_size)
        end
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
          process_download(url, size, path, last: index == SIZES.size - 1)
        end
      end

      # Builds URL for a specific variant and size
      #
      # @param variant_id [String] Weapon variant ID
      # @param size [String] Image size variant ("main", "grid", "square", or "raw")
      # @return [String] Complete URL for downloading the image
      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)
        if size == 'raw'
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
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/weapon'
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "main" -> "ls", "grid" -> "m", "square" -> "s"
      def directory_for_size(size)
        case size.to_s
        when 'main' then 'ls'
        when 'grid' then 'm'
        when 'square' then 's'
        when 'raw' then 'b'
        end
      end
    end
  end
end
