# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads a Wonder's art from the game CDN to `wonders/<image>.jpg`.
    #
    # The game has one 130x130 size (`s/`). Leveled Wonders (Crucible Seals,
    # Yupei) are shown as `<id>_<level>`, and the CDN serves a file for every
    # level, so each level is copied and the web app never needs to know
    # where the art changes. Symbolum Amicitiae's art varies with the
    # character count (`9015_2` .. `9015_11`); missing suffixes 404 and are
    # skipped.
    #
    # @example
    #   WonderDownloader.new('9008', storage: :s3).download
    class WonderDownloader < BaseDownloader
      SIZES = %w[square].freeze
      BASE_URL = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/item/memorial/s'
      # Symbolum's known art suffixes are 2..11; probe a little past that.
      SCALING_SUFFIXES = (1..20)
      # Pause between CDN requests
      THROTTLE = 0.3

      def download(_selected_size = nil)
        wonder = Wonder.find_by(granblue_id: @id)
        return unless wonder

        log_info("-> #{@id}")
        return if @test_mode

        names = image_names(wonder)
        names.each_with_index do |name, index|
          process_download("#{BASE_URL}/#{name}.jpg", 'square', download_path('square'), last: index == names.size - 1)
          sleep THROTTLE unless index == names.size - 1
        end
      end

      # Every image name a Wonder can show.
      # @return [Array<String>]
      def image_names(wonder)
        base = wonder.granblue_id
        case wonder.kind
        when 'leveled' then [base] + (1..wonder.max_level.to_i).map { |level| "#{base}_#{level}" }
        when 'scaling' then [base] + SCALING_SUFFIXES.map { |suffix| "#{base}_#{suffix}" }
        else [base]
        end
      end

      private

      def object_type
        'wonder'
      end

      def base_url
        BASE_URL
      end

      def directory_for_size(_size)
        's'
      end

      # One size, so no size folder: wonders/<image>.jpg
      def build_s3_key(_size, filename)
        "#{bucket_directory}/#{filename}"
      end

      def download_path(_size)
        Rails.root.join('download/wonders').to_s
      end
    end
  end
end
