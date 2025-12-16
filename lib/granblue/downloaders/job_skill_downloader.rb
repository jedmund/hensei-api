# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads job skill icon images from the game server.
    # Job skills have a single icon image format.
    #
    # @example Download image for a specific job skill
    #   downloader = JobSkillDownloader.new("2710_3", slug: "unlimited-boost", storage: :s3)
    #   downloader.download
    #
    # @note Job skill icons are PNG format
    # @note Images are fetched using image_id but stored using slug
    class JobSkillDownloader < BaseDownloader
      # Job skill images have only one size: icon
      SIZES = %w[icon].freeze

      # Initialize with image_id and slug
      # @param image_id [String] The image ID to download from game server
      # @param slug [String] The slug to use for storage filename
      # @param options [Hash] Additional options passed to BaseDownloader
      def initialize(image_id, slug:, **options)
        @slug = slug
        super(image_id, **options)
      end

      # Downloads the icon image for a job skill
      #
      # @param selected_size [String] The size to download (ignored, only icon exists)
      # @return [Hash] Result with :success key
      def download(selected_size = nil)
        log_info("-> #{@id} (storing as #{@slug})") if @verbose
        return { success: false } if @test_mode

        path = download_path('icon')
        url = build_url('icon')
        filename = "#{@slug}.png"
        s3_key = build_s3_key('icon', filename)
        download_uri = "#{path}/#{filename}"

        should_process = should_download?(download_uri, s3_key)
        return { success: true, skipped: true } unless should_process

        log_info "\t└ icon: #{url} -> #{@slug}.png..."

        case @storage
        when :local
          download_to_local(url, download_uri)
        when :s3
          stream_to_s3(url, s3_key)
        when :both
          download_to_both(url, download_uri, s3_key)
        end

        { success: true }
      rescue OpenURI::HTTPError => e
        log_info "\t404 returned\t#{url}"
        { success: false, error: e.message }
      rescue StandardError => e
        log_info "\tError downloading #{url}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      # Gets object type for file paths and storage keys
      # @return [String] Returns "job-skills" to match existing S3 bucket structure
      def object_type
        'job-skills'
      end

      # Override to not append size to the key (job skills only have one size)
      # @param size [String] Image size variant (ignored)
      # @param filename [String] Image filename
      # @return [String] Complete S3 key
      def build_s3_key(size, filename)
        "#{object_type}/#{filename}"
      end

      # Override download path to not append size
      # @param size [String] Image size variant (ignored)
      # @return [String] Local directory path
      def download_path(size)
        "#{Rails.root}/download/#{object_type}"
      end

      # Gets base URL for job skill assets
      # @return [String] Base URL for job skill images
      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/ui/icon/ability/m'
      end

      # Gets directory name for a size variant (not used for job skills)
      #
      # @param size [String] Image size variant
      # @return [nil] Job skills don't use subdirectories
      def directory_for_size(size)
        nil
      end

      # Build complete URL for the job skill icon
      # @param size [String] Image size variant (ignored)
      # @return [String] Complete download URL
      def build_url(size)
        "#{base_url}/#{@id}.png"
      end
    end
  end
end
