# frozen_string_literal: true

module Granblue
  module Downloader
    class SummonDownloader < BaseDownloader
      def download
        summon = Summon.find_by(granblue_id: @id)
        return unless summon

        download_variants(summon)
      end

      private

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
        'summon'
      end

      def base_url
        'http://gbf.game-a.mbga.jp/assets/img/sp/assets/summon'
      end

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
