# frozen_string_literal: true

module Granblue
  module Downloaders
    # Abstract base class for downloading game asset images in various sizes.
    # Handles local and S3 storage, with support for test mode and verbose logging.
    #
    # @abstract Subclass must implement {#object_type}, {#base_url}, and {#directory_for_size}
    #
    # @example Downloading assets for a specific ID
    #   class MyDownloader < BaseDownloader
    #     def object_type; "weapon"; end
    #     def base_url; "http://example.com/assets"; end
    #     def directory_for_size(size)
    #       case size
    #       when "main" then "large"
    #       when "grid" then "medium"
    #       when "square" then "small"
    #       end
    #     end
    #   end
    #
    #   downloader = MyDownloader.new("1234", storage: :both)
    #   downloader.download
    #
    # @note Supports three image sizes: main, grid, and square
    # @note Can store images locally, in S3, or both
    class BaseDownloader
      # @return [Array<String>] Available image size variants
      SIZES = %w[main grid square].freeze

      # Initialize a new downloader instance
      # @param id [String] ID of the object to download images for
      # @param test_mode [Boolean] When true, only logs actions without downloading
      # @param verbose [Boolean] When true, enables detailed logging
      # @param storage [Symbol] Storage mode (:local, :s3, or :both)
      # @return [void]
      def initialize(id, test_mode: false, verbose: false, storage: :both)
        @id = id
        @base_url = base_url
        @test_mode = test_mode
        @verbose = verbose
        @storage = storage
        @aws_service = AwsService.new
        ensure_directories_exist unless @test_mode
      end

      # Download images for all sizes
      # @return [void]
      def download
        log_info "-> #{@id}"
        return if @test_mode

        SIZES.each_with_index do |size, index|
          path = download_path(size)
          url = build_url(size)
          process_download(url, size, path, last: index == SIZES.size - 1)
        end
      end

      private

      # Process download for a specific size variant
      # @param url [String] URL to download from
      # @param size [String] Size variant being processed
      # @param path [String] Local path for download
      # @param last [Boolean] Whether this is the last size being processed
      # @return [void]
      def process_download(url, size, path, last: false)
        filename = File.basename(url)
        s3_key = build_s3_key(size, filename)
        download_uri = "#{path}/#{filename}"

        should_process = should_download?(download_uri, s3_key)
        return unless should_process

        if last
          log_info "\t└ #{size}: #{url}..."
        else
          log_info "\t├ #{size}: #{url}..."
        end

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

      # Download file to local storage
      # @param url [String] Source URL
      # @param download_uri [String] Local destination path
      # @return [void]
      def download_to_local(url, download_uri)
        download = URI.parse(url).open
        IO.copy_stream(download, download_uri)
      end

      # Stream file directly to S3
      # @param url [String] Source URL
      # @param s3_key [String] S3 object key
      # @return [void]
      def stream_to_s3(url, s3_key)
        return if @aws_service.file_exists?(s3_key)

        URI.parse(url).open do |file|
          @aws_service.upload_stream(file, s3_key)
        end
      end

      # Download file to both local storage and S3
      # @param url [String] Source URL
      # @param download_uri [String] Local destination path
      # @param s3_key [String] S3 object key
      # @return [void]
      def download_to_both(url, download_uri, s3_key)
        download = URI.parse(url).open

        # Write to local file
        IO.copy_stream(download, download_uri)

        # Reset file pointer for S3 upload
        download.rewind

        # Upload to S3 if it doesn't exist
        unless @aws_service.file_exists?(s3_key)
          @aws_service.upload_stream(download, s3_key)
        end
      end

      # Check if file should be downloaded based on storage mode
      # @param local_path [String] Local file path
      # @param s3_key [String] S3 object key
      # @return [Boolean] true if file should be downloaded
      def should_download?(local_path, s3_key)
        if @storage == :local
          !File.exist?(local_path)
        elsif @storage == :s3
          !@aws_service.file_exists?(s3_key)
        else
          # :both
          !File.exist?(local_path) || !@aws_service.file_exists?(s3_key)
        end
      end

      # Ensure local directories exist for each size
      # @return [void]
      def ensure_directories_exist
        return unless store_locally?

        SIZES.each do |size|
          FileUtils.mkdir_p(download_path(size))
        end
      end

      # Check if local storage is being used
      # @return [Boolean] true if storing locally
      def store_locally?
        %i[local both].include?(@storage)
      end

      # Get local download path for a size
      # @param size [String] Image size variant
      # @return [String] Local directory path
      def download_path(size)
        "#{Rails.root}/download/#{object_type}-#{size}"
      end

      # Build S3 key for an image
      # @param size [String] Image size variant
      # @param filename [String] Image filename
      # @return [String] Complete S3 key
      def build_s3_key(size, filename)
        "#{object_type}-#{size}/#{filename}"
      end

      # Log informational message if verbose
      # @param message [String] Message
      def log_info(message)
        puts message if @verbose
      end

      # Download elemental variant image
      # @param url [String] Source URL
      # @param size [String] Image size variant
      # @param path [String] Destination path
      # @param filename [String] Image filename
      # @return [void]
      def download_elemental_image(url, size, path, filename)
        return if @test_mode

        filepath = "#{path}/#{filename}"
        URI.open(url) do |file|
          content = file.read
          if content
            File.open(filepath, 'wb') do |output|
              output.write(content)
            end
          else
            raise "Failed to read content from #{url}"
          end
        end
        log_info "-> #{size}:\t#{url}..."
      rescue OpenURI::HTTPError
        log_info "\t404 returned\t#{url}"
      rescue StandardError => e
        log_info "\tError downloading #{url}: #{e.message}"
      end

      # Get asset type (e.g., "weapon", "character")
      # @abstract
      # @return [String] Asset type name
      def object_type
        raise NotImplementedError, 'Subclasses must define object_type'
      end

      # Get base URL for assets
      # @abstract
      # @return [String] Base URL
      def base_url
        raise NotImplementedError, 'Subclasses must define base_url'
      end

      # Get directory name for a size variant
      # @abstract
      # @param size [String] Image size variant
      # @return [String] Directory name
      def directory_for_size(size)
        raise NotImplementedError, 'Subclasses must define directory_for_size'
      end

      # Build complete URL for a size variant
      # @param size [String] Image size variant
      # @return [String] Complete download URL
      def build_url(size)
        directory = directory_for_size(size)
        "#{@base_url}/#{directory}/#{@id}.jpg"
      end
    end
  end
end
