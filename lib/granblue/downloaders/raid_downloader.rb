# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads raid image assets from the game server.
    # Raids have two different image types from different sources:
    # - Icon: from enemy directory using enemy_id
    # - Thumbnail: from summon directory using summon_id
    #
    # @example Download images for a specific raid
    #   downloader = RaidDownloader.new(raid, storage: :both)
    #   downloader.download
    #
    # @note Unlike other downloaders, RaidDownloader takes a Raid model instance
    #   since it needs both enemy_id and summon_id
    class RaidDownloader < BaseDownloader
      SIZES = %w[icon thumbnail].freeze

      ICON_BASE_URL = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/enemy'
      THUMBNAIL_BASE_URL = 'https://prd-game-a1-granbluefantasy.akamaized.net/assets_en/img/sp/assets/summon'

      # Initialize with a Raid model instead of just an ID
      # @param raid [Raid] Raid model instance
      # @param test_mode [Boolean] When true, only logs actions without downloading
      # @param verbose [Boolean] When true, enables detailed logging
      # @param storage [Symbol] Storage mode (:local, :s3, or :both)
      # @param force [Boolean] When true, re-downloads even if file exists
      def initialize(raid, test_mode: false, verbose: false, storage: :both, force: false, logger: nil)
        @raid = raid
        @id = raid.slug # Use slug for logging
        @test_mode = test_mode
        @verbose = verbose
        @storage = storage
        @force = force
        @logger = logger || Logger.new($stdout)
        @aws_service = self.class.aws_service if store_in_s3?
        ensure_directories_exist unless @test_mode
      end

      # Download images for all available sizes
      # @param selected_size [String] The size to download ('icon', 'thumbnail', or nil for all)
      # @return [void]
      def download(selected_size = nil)
        log_info("-> #{@raid.slug}")
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES

        sizes.each_with_index do |size, index|
          case size
          when 'icon'
            download_icon(last: index == sizes.size - 1)
          when 'thumbnail'
            download_thumbnail(last: index == sizes.size - 1)
          end
        end
      end

      private

      # Download the icon image (from enemy directory)
      def download_icon(last: false)
        return unless @raid.enemy_id

        path = download_path('icon')
        url = build_icon_url
        filename = "#{@raid.enemy_id}.png"
        s3_key = build_s3_key('icon', filename)
        download_uri = "#{path}/#{filename}"

        return unless should_download?(download_uri, s3_key)

        log_download('icon', url, last: last)
        process_image_download(url, download_uri, s3_key)
      rescue OpenURI::HTTPError
        log_info "\t404 returned\t#{url}"
      end

      # Download the thumbnail image (from summon directory)
      def download_thumbnail(last: false)
        return unless @raid.summon_id

        path = download_path('thumbnail')
        url = build_thumbnail_url
        filename = "#{@raid.summon_id}_high.png"
        s3_key = build_s3_key('thumbnail', filename)
        download_uri = "#{path}/#{filename}"

        return unless should_download?(download_uri, s3_key)

        log_download('thumbnail', url, last: last)
        process_image_download(url, download_uri, s3_key)
      rescue OpenURI::HTTPError
        log_info "\t404 returned\t#{url}"
      end

      def log_download(size, url, last: false)
        if last
          log_info "\t└ #{size}: #{url}..."
        else
          log_info "\t├ #{size}: #{url}..."
        end
      end

      def process_image_download(url, download_uri, s3_key)
        case @storage
        when :local
          download_to_local(url, download_uri)
        when :s3
          stream_to_s3(url, s3_key)
        when :both
          download_to_both(url, download_uri, s3_key)
        end
      end

      def build_icon_url
        "#{ICON_BASE_URL}/m/#{@raid.enemy_id}.png"
      end

      def build_thumbnail_url
        "#{THUMBNAIL_BASE_URL}/qm/#{@raid.summon_id}_high.png"
      end

      def object_type
        'raid'
      end

      # Not used for raids since we have custom URLs
      def base_url
        nil
      end

      # Not used for raids since we have custom URL building
      def directory_for_size(_size)
        nil
      end
    end
  end
end
