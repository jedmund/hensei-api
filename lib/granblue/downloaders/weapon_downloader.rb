# frozen_string_literal: true

module Granblue
  module Downloader
    class WeaponDownloader < BaseDownloader
      private

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
