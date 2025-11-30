# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads job image assets from the game server in different sizes and variants.
    # Handles job-specific images including wide and zoom formats with gender variants.
    #
    # @example Download images for a specific job
    #   downloader = JobDownloader.new("100401", storage: :both)
    #   downloader.download
    #
    # @note Job images come in wide and zoom formats only
    # @note Zoom images have male (0) and female (1) variants
    class JobDownloader < BaseDownloader
      # Override SIZES to include only 'wide' and 'zoom' for job images
      SIZES = %w[wide zoom].freeze

      # Downloads images for all variants of a job.
      # Overrides {BaseDownloader#download} to handle job-specific variants.
      #
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      # @note Skips download if job is not found in database
      # @note Downloads gender variants for zoom images
      def download(selected_size = nil)
        job = Job.find_by(granblue_id: @id)
        return unless job

        download_variants(job, selected_size)
      end

      private

      # Downloads all variants of a job's images
      #
      # @param job [Job] Job model instance to download images for
      # @param selected_size [String] The size to download. If nil, downloads all sizes.
      # @return [void]
      def download_variants(job, selected_size = nil)
        log_info "-> #{@id}" if @verbose
        return if @test_mode

        sizes = selected_size ? [selected_size] : SIZES

        sizes.each_with_index do |size, index|
          case size
          when 'zoom'
            # Download both male and female variants for zoom images
            download_zoom_variants(index == sizes.size - 1)
          when 'wide'
            # Download both male and female variants for wide images
            download_wide_variants(index == sizes.size - 1)
          end
        end
      end

      # Downloads zoom variants for both genders
      #
      # @param is_last [Boolean] Whether zoom is the last size being processed
      # @return [void]
      def download_zoom_variants(is_last)
        path = download_path('zoom')

        # Download male variant (_a suffix, 0 in URL)
        url_male = build_zoom_url(0)
        filename_male = "#{@id}_a.png"
        download_variant(url_male, 'zoom', path, filename_male, 'zoom-male', last: false)

        # Download female variant (_b suffix, 1 in URL)
        url_female = build_zoom_url(1)
        filename_female = "#{@id}_b.png"
        download_variant(url_female, 'zoom', path, filename_female, 'zoom-female', last: is_last)
      end

      # Downloads a specific variant
      #
      # @param url [String] URL to download from
      # @param size [String] Size category for S3 key
      # @param path [String] Local path for download
      # @param filename [String] Filename to save as
      # @param label [String] Label for logging
      # @param last [Boolean] Whether this is the last item being processed
      # @return [void]
      def download_variant(url, size, path, filename, label, last: false)
        s3_key = build_s3_key(size, filename)
        download_uri = "#{path}/#{filename}"

        should_process = should_download?(download_uri, s3_key)
        return unless should_process

        prefix = last ? "\t└" : "\t├"
        log_info "#{prefix} #{label}: #{url}..."

        case @storage
        when :local
          download_to_local(url, download_uri)
        when :s3
          stream_to_s3(url, s3_key)
        when :both
          download_to_both(url, download_uri, s3_key)
        end
      rescue OpenURI::HTTPError
        log_info "\t404 returned\t#{url}"
      end

      # Builds URL for wide images
      #
      # @param size [String] Image size variant
      # @return [String] Complete URL for downloading the image
      def build_job_url(size)
        case size
        when 'wide'
          # Wide images always download both male and female variants
          nil # Will be handled by download_wide_variants
        when 'zoom'
          nil # Handled by build_zoom_url
        else
          nil
        end
      end

      # Downloads wide variants for both genders
      #
      # @param is_last [Boolean] Whether wide is the last size being processed
      # @return [void]
      def download_wide_variants(is_last)
        path = download_path('wide')

        # Download male variant (_a suffix, _01 in URL)
        url_male = "https://prd-game-a3-granbluefantasy.akamaized.net/assets_en/img/sp/assets/leader/m/#{@id}_01.jpg"
        filename_male = "#{@id}_a.jpg"
        download_variant(url_male, 'wide', path, filename_male, 'wide-male', last: false)

        # Download female variant (_b suffix, _01 in URL - same as male for wide)
        url_female = "https://prd-game-a3-granbluefantasy.akamaized.net/assets_en/img/sp/assets/leader/m/#{@id}_01.jpg"
        filename_female = "#{@id}_b.jpg"
        download_variant(url_female, 'wide', path, filename_female, 'wide-female', last: is_last)
      end

      # Builds URL for zoom images with gender variant
      #
      # @param gender [Integer] Gender variant (0 for male, 1 for female)
      # @return [String] Complete URL for downloading the zoom image
      def build_zoom_url(gender)
        "https://media.skycompass.io/assets/customizes/jobs/1138x1138/#{@id}_#{gender}.png"
      end


      # Gets object type for file paths and storage keys
      # @return [String] Returns "job"
      def object_type
        'job'
      end

      # Gets base URL for job assets
      # @return [String] Base URL for job images
      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/leader'
      end

      # Gets directory name for a size variant
      #
      # @param size [String] Image size variant
      # @return [String] Directory name in game asset URL structure
      # @note Jobs only have wide and zoom formats, handled with custom URLs
      def directory_for_size(size)
        nil # Jobs don't use the standard directory structure
      end
    end
  end
end