# frozen_string_literal: true

module Granblue
  module Downloader
    class CharacterDownloader < BaseDownloader
      private

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
