# frozen_string_literal: true

class PostDeploymentManager
  STORAGE_DESCRIPTIONS = {
    local: 'to local disk',
    s3: 'to S3',
    both: 'to local disk and S3'
  }.freeze

  def initialize(options = {})
    @test_mode = options.fetch(:test_mode, false)
    @verbose = options.fetch(:verbose, false)
    @storage = options.fetch(:storage, :both)
    @new_records = Hash.new { |h, k| h[k] = [] }
  end

  def run
    import_new_data
    display_import_summary
    download_images
  end

  private

  def import_new_data
    log_step 'Importing new data...'
    importer = Granblue::DataImporter.new(
      test_mode: @test_mode,
      verbose: @verbose
    )

    process_imports(importer)
  end

  def process_imports(importer)
    importer.process_all_files do |file_records|
      file_records.each do |type, ids|
        @new_records[type].concat(ids)
      end
    end
  end

  def display_import_summary
    log_step "\nImport Summary:"
    @new_records.each do |type, ids|
      puts "#{type.capitalize}: #{ids.size} new records"
      puts "IDs: #{ids.inspect}" if @verbose
    end
  end

  def download_images
    return if all_records_empty?

    if @test_mode
      log_step "\nTEST MODE: Would download images for new records..."
    else
      log_step "\nDownloading images for new records..."
    end

    @new_records.each do |type, ids|
      next if ids.empty?

      download_type_images(type, ids)
    end
  end

  def download_type_images(type, ids)
    log_step "\nProcessing new #{type.pluralize} (#{ids.size} records)..."
    download_options = {
      test_mode: @test_mode,
      verbose: @verbose,
      storage: @storage
    }

    ids.each do |id|
      download_single_image(type, id, download_options)
    end
  end

  def download_single_image(type, id, options)
    action_text = @test_mode ? 'Would download' : 'Downloading'
    storage_text = STORAGE_DESCRIPTIONS[options[:storage]]
    log_verbose "#{action_text} images #{storage_text} for #{type} #{id}..."

    Granblue::Downloader::DownloadManager.download_for_object(
      type,
      id,
      **options
    )
  rescue => e
    error_message = "Error #{@test_mode ? 'would occur' : 'occurred'} downloading images for #{type} #{id}: #{e.message}"
    puts error_message
    puts e.backtrace.take(5) if @verbose
  end

  def all_records_empty?
    @new_records.values.all?(&:empty?)
  end

  def log_step(message)
    puts message
  end

  def log_verbose(message)
    puts message if @verbose
  end
end
