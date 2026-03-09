namespace :granblue do
  desc 'Downloads images for the given Granblue_IDs'
  task :download_images, %i[object] => :environment do |_t, args|
    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', 'image_downloader', '*.rb')].each { |file| require file }

    object = args[:object]
    list = args.extras

    list.each do |id|
      Granblue::Downloader::DownloadManager.download_for_object(object, id)
    end
  end

  desc 'Downloads images for weapons with null element (element == 0)'
  task :download_null_weapon_images, %i[threads size force storage] => :environment do |_t, args|
    require 'parallel'
    require 'logger'

    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', 'downloaders', '*.rb')].each { |file| require file }

    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    log_path = Rails.root.join('log', "download_null_weapons_#{timestamp}.log")
    logger = Logger.new(log_path)
    logger.level = Logger::INFO

    specified_size = args[:size]
    force = args[:force].to_s == 'true'
    storage = (args[:storage] || 'both').to_sym
    thread_count = (args[:threads] || 4).to_i

    ids = Weapon.where(element: 0).pluck(:granblue_id)

    puts "Downloading images for #{ids.count} null-element weapons..."
    puts "Logging to #{log_path}"
    logger.info "Downloading images for #{ids.count} null-element weapons..."
    logger.info "Using #{thread_count} threads for parallel downloads..."
    logger.info "Downloading only size: #{specified_size}" if specified_size

    Parallel.each(ids, in_threads: thread_count) do |id|
      ActiveRecord::Base.connection_pool.with_connection do
        downloader = Granblue::Downloaders::WeaponDownloader.new(id, verbose: true, force: force, storage: storage, logger: logger)
        if specified_size
          downloader.download(specified_size)
        else
          downloader.download
        end
      rescue StandardError => e
        logger.error "Error downloading weapon #{id}: #{e.message}"
      end
    end
  end

  desc 'Downloads elemental weapon images'
  task :download_elemental_images, [:id_base] => :environment do |_t, args|
    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', 'image_downloader', '*.rb')].each { |file| require file }

    Granblue::Downloader::ElementalWeaponDownloader.new(args[:id_base]).download
  end
end
