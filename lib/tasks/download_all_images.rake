namespace :granblue do
  desc 'Downloads all images for the given object type'
  # Downloads all images for a specific type of game object (e.g. summons, weapons)
  # Uses the appropriate downloader class based on the object type
  #
  # @param object [String] Type of object to download images for (e.g. 'summon', 'weapon')
  # @example Download all summon images
  #   rake granblue:download_all_images\[summon\]
  # @example Download all weapon images
  #   rake granblue:download_all_images\[weapon\]
  # @example Download all character images
  #   rake granblue:download_all_images\[character\]
  task :download_all_images, %i[object threads size] => :environment do |_t, args|
    require 'parallel'
    require 'logger'

    # Use a thread-safe logger (or Rails.logger if preferred)
    logger = Logger.new($stdout)
    logger.level = Logger::INFO # set to WARN or INFO to reduce debug noise

    # Load downloader classes
    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', 'downloaders', '*.rb')].each { |file| require file }

    object = args[:object]
    specified_size = args[:size]
    klass = object.classify.constantize
    ids = klass.pluck(:granblue_id)

    puts "Downloading images for #{ids.count} #{object.pluralize}..."

    logger.info "Downloading images for #{ids.count} #{object.pluralize}..."
    thread_count = (args[:threads] || 4).to_i
    logger.info "Using #{thread_count} threads for parallel downloads..."
    logger.info "Downloading only size: #{specified_size}" if specified_size

    Parallel.each(ids, in_threads: thread_count) do |id|
      ActiveRecord::Base.connection_pool.with_connection do
        downloader_class = "Granblue::Downloaders::#{object.classify}Downloader".constantize
        downloader = downloader_class.new(id, verbose: true, logger: logger)
        if specified_size
          downloader.download(specified_size)
        else
          downloader.download
        end
      rescue StandardError => e
        logger.error "Error downloading #{object} #{id}: #{e.message}"
      end
    end
  end
end
