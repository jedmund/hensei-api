# frozen_string_literal: true

module Granblue
  module Downloaders
    class BulletDownloader < BaseDownloader
      SIZES = %w[square].freeze

      def download(selected_size = nil)
        bullet = Bullet.find_by(granblue_id: @id)
        return unless bullet

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

      def object_type
        'bullet'
      end

      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/bullet'
      end

      def directory_for_size(size)
        case size.to_s
        when 'square' then 's'
        end
      end
    end
  end
end
