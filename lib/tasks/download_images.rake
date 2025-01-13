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

  desc 'Downloads elemental weapon images'
  task :download_elemental_images, [:id_base] => :environment do |_t, args|
    require_relative '../granblue/downloaders/base_downloader'
    Dir[Rails.root.join('lib', 'granblue', 'image_downloader', '*.rb')].each { |file| require file }

    Granblue::Downloader::ElementalWeaponDownloader.new(args[:id_base]).download
  end
end
