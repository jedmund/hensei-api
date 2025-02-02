# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads summon image assets from the game server in different sizes and variants.
    # Handles summon-specific variants like base art, ULB art, and transcendence art.
    #
    # @example Download images for a specific summon
    #   downloader = SummonDownloader.new("2040001000", storage: :both)
    #   downloader.download
    #
    # @note Summon images come in multiple variants based on uncap status
    # @note Supports ULB (5★) and transcendence variants when available
    class SummonDownloader < BaseDownloader
      # Downloads images for all variants of a summon based on their uncap status.
      # Overrides {BaseDownloader#download} to handle summon-specific variants.
      #
      # @return [void]
      # @note Skips download if summon is not found in database
      # @note Downloads ULB and transcendence variants only if summon has those uncaps
      # @see #download_variants
      def download
        summon = Summon.find_by(granblue_id: @id)
        return unless summon

        download_variants(summon)
      end

      private

      # Downloads all variants of a summon's images
      # @param summon [Summon] Summon model instance to download images for
      # @return [void]
      # @note Only downloads variants that should exist based on summon uncap status
      # @note Handles special transcendence art variants for 6★ summons
      def download_variants(summon)
        # All summons have base variant
        variants = [@id]

        # Add ULB variant if available
        variants << "#{@id}_02" if summon.ulb

        # Add Transcendence variants if available
        if summon.transcendence
          variants.push("#{@id}_03", "#{@id}_04")
        end

        log_info "Downloading summon variants: #{variants.join(', ')}" if @verbose

        variants.each do |variant_id|
          download_variant(variant_id)
        end
      end

      # Downloads a specific variant's images in all sizes
      # @param variant_id [String] Summon variant ID (e.g., "2040001000_02")
      # @return [void]
      # @note Downloads all size variants (main/grid/square) for the given variant
      def download_variant(variant_id)
        log_info "-> #{variant_id}" if @verbose
        return if @test_mode

        SIZES.each_with_index do |size, index|
          path = download_path(size)
          url = build_variant_url(variant_id, size)
          process_download(url, size, path, last: index == SIZES.size - 1)
        end
      end

      # Builds URL for a specific variant and size
      # @param variant_id [String] Summon variant ID
      # @param size [String] Image size variant ("main", "grid", or "square")
      # @return [String] Complete URL for downloading the image
      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)
        "#{@base_url}/#{directory}/#{variant_id}.jpg"
      end

      # Gets object type for file paths and storage keys
      # @return [String] Returns "summon"
      def object_type
        'summon'
      end

      # Gets base URL for summon assets
      # @return [String] Base URL for summon images
      def base_url
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/summon'
      end

      # Gets directory name for a size variant
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Maps "main" -> "party_main", "grid" -> "party_sub", "square" -> "s"
      def directory_for_size(size)
        case size.to_s
        when 'main' then 'party_main'
        when 'grid' then 'party_sub'
        when 'square' then 's'
        end
      end
    end
  end
end
