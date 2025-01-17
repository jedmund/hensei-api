# frozen_string_literal: true

module Granblue
  module Downloaders
    class CharacterDownloader < BaseDownloader
      def download
        character = Character.find_by(granblue_id: @id)
        return unless character

        download_variants(character)
      end

      private

      def download_variants(character)
        # All characters have 01 and 02 variants
        variants = ["#{@id}_01", "#{@id}_02"]

        # Add FLB variant if available
        variants << "#{@id}_03" if character.flb

        # Add ULB variant if available
        variants << "#{@id}_04" if character.ulb

        log_info "Downloading character variants: #{variants.join(', ')}" if @verbose

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
        'character'
      end

      def base_url
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/npc'
      end

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
