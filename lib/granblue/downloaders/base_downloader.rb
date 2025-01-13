# frozen_string_literal: true

module Granblue
  module Downloader
    class BaseDownloader
      SIZES = %w[main grid square].freeze

      def initialize(id, test_mode: false, verbose: false, storage: :both)
        @id = id
        @base_url = base_url
        @test_mode = test_mode
        @verbose = verbose
        @storage = storage
        @aws_service = AwsService.new
        ensure_directories_exist unless @test_mode
      end

      def download
        log_info "=> #{@id}"
        return if @test_mode

        SIZES.each do |size|
          path = download_path(size)
          url = build_url(size)
          process_download(url, size, path)
        end
      end

      private

      def process_download(url, size, path)
        filename = File.basename(url)
        s3_key = build_s3_key(size, filename)
        download_uri = "#{path}/#{filename}"

        should_process = should_download?(download_uri, s3_key)
        return unless should_process

        log_info "-> #{size}: #{url}..."

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

      def download_to_local(url, download_uri)
        download = URI.parse(url).open
        IO.copy_stream(download, download_uri)
      end

      def stream_to_s3(url, s3_key)
        return if @aws_service.file_exists?(s3_key)

        URI.parse(url).open do |file|
          @aws_service.upload_stream(file, s3_key)
        end
      end

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

      def should_download?(local_path, s3_key)
        case @storage
        when :local
          !File.exist?(local_path)
        when :s3
          !@aws_service.file_exists?(s3_key)
        when :both
          !File.exist?(local_path) || !@aws_service.file_exists?(s3_key)
        end
      end

      def ensure_directories_exist
        return unless store_locally?

        SIZES.each do |size|
          FileUtils.mkdir_p(download_path(size))
        end
      end

      def store_locally?
        %i[local both].include?(@storage)
      end

      def download_path(size)
        "#{Rails.root}/download/#{object_type}-#{size}"
      end

      def build_s3_key(size, filename)
        "#{object_type}-#{size}/#{filename}"
      end

      def log_info(message)
        puts message if @verbose
      end

      def download_elemental_image(url, size, path, filename)
        return if @test_mode

        filepath = "#{path}/#{filename}"
        download = URI.parse(url).open
        log_info "-> #{size}:\t#{url}..."
        IO.copy_stream(download, filepath)
      rescue OpenURI::HTTPError
        log_info "\t404 returned\t#{url}"
      end

      def object_type
        raise NotImplementedError, 'Subclasses must define object_type'
      end

      def base_url
        raise NotImplementedError, 'Subclasses must define base_url'
      end

      def directory_for_size(size)
        raise NotImplementedError, 'Subclasses must define directory_for_size'
      end

      def build_url(size)
        directory = directory_for_size(size)
        "#{@base_url}/#{directory}/#{@id}.jpg"
      end
    end
  end
end
