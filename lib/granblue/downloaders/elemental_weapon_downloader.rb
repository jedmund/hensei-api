# frozen_string_literal: true

require_relative 'weapon_downloader'

module Granblue
  module Downloaders
    # Specialized downloader for handling elemental weapon variants.
    # Some weapons have different art for each element, requiring multiple downloads.
    #
    # @example Download all elemental variants
    #   downloader = ElementalWeaponDownloader.new(1040001000)
    #   downloader.download
    #
    # @note Handles weapons that have variants for all six elements
    # @note Uses specific suffix mappings for element art variants
    class ElementalWeaponDownloader < WeaponDownloader
      # Element variant suffix mapping
      # @return [Array<Integer>] Ordered list of suffixes for element variants
      SUFFIXES = [2, 3, 4, 1, 6, 5].freeze

      # Initialize downloader with base weapon ID
      # @param id_base [Integer] Base ID for the elemental weapon series
      # @return [void]
      def initialize(id_base)
        @id_base = id_base.to_i
      end

      # Downloads all elemental variants of the weapon
      # @return [void]
      # @note Downloads variants for all six elements
      # @note Uses progress reporter to show download status
      def download
        (1..6).each do |i|
          id = @id_base + (i - 1) * 100
          suffix = SUFFIXES[i - 1]

          puts "Elemental Weapon #{id}_#{suffix}"
          SIZES.each do |size|
            path = download_path(size)
            url = build_url_for_id(id, size)
            filename = "#{id}_#{suffix}.jpg"
            download_elemental_image(url, size, path, filename)
          end

          progress_reporter(count: i, total: 6, result: "Elemental Weapon #{id}_#{suffix}")
        end
      end

      private

      def build_url_for_id(id, size)
        directory = directory_for_size(size)
        "#{base_url}/#{directory}/#{id}.jpg"
      end

      def progress_reporter(count:, total:, result:, bar_len: 40)
        filled_len = (bar_len * count / total).round
        status = result
        percents = (100.0 * count / total).round(1)
        bar = '=' * filled_len + '-' * (bar_len - filled_len)
        print("\n[#{bar}] #{percents}% ...#{' ' * 14}#{status}\n")
      end
    end
  end
end
