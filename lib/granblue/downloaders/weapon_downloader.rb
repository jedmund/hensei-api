# frozen_string_literal: true

module Granblue
  module Downloaders
    class WeaponDownloader < BaseDownloader
      def download
        weapon = Weapon.find_by(granblue_id: @id)
        return unless weapon

        download_variants(weapon)
      end

      private

      def download_variants(weapon)
        # All weapons have base variant
        variants = [@id]

        # Add transcendence variants if available
        if weapon.transcendence
          variants.push("#{@id}_02", "#{@id}_03")
        end

        log_info "Downloading weapon variants: #{variants.join(', ')}" if @verbose

        variants.each do |variant_id|
          download_variant(variant_id)
        end
      end

      def download_variant(variant_id)
        log_info "-> #{variant_id}" if @verbose
        return if @test_mode

        SIZES.each_with_index do |size, index|
          path = download_path(size)
          url = build_variant_url(variant_id, size)
          process_download(url, size, path, last: index == SIZES.size - 1)
        end
      end

      def build_variant_url(variant_id, size)
        directory = directory_for_size(size)
        "#{@base_url}/#{directory}/#{variant_id}.jpg"
      end

      def object_type
        'weapon'
      end

      def base_url
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/weapon'
      end

      def directory_for_size(size)
        case size.to_s
        when 'main' then 'ls'
        when 'grid' then 'm'
        when 'square' then 's'
        end
      end
    end
  end
end
