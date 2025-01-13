# frozen_string_literal: true

module Granblue
  module Downloader
    class SummonDownloader < BaseDownloader
      private

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
