namespace :granblue do
  def _progress_reporter(count:, total:, result:, bar_len: 40, multi: true)
    filled_len = (bar_len * count / total).round
    status = File.basename(result)
    percents = (100.0 * count / total).round(1)
    bar = '=' * filled_len + '-' * (bar_len - filled_len)

    if !multi
      print("[#{bar}] #{percents}% ...#{' ' * 14}#{status}\n")
    else
      print "\n"
    end
  end

  def build_weapon_url(id, size)
    # Set up URL
    base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/weapon'
    extension = '.jpg'

    directory = 'ls' if size.to_s == 'main'
    directory = 'm' if size.to_s == 'grid'
    directory = 's' if size.to_s == 'square'

    "#{base_url}/#{directory}/#{id}#{extension}"
  end

  def build_summon_url(id, size)
    # Set up URL
    base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/summon'
    extension = '.jpg'

    directory = 'party_main' if size.to_s == 'main'
    directory = 'party_sub' if size.to_s == 'grid'
    directory = 's' if size.to_s == 'square'

    "#{base_url}/#{directory}/#{id}#{extension}"
  end

  def build_chara_url(id, size)
    # Set up URL
    base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/npc'
    extension = '.jpg'

    directory = 'f' if size.to_s == 'main'
    directory = 'm' if size.to_s == 'grid'
    directory = 's' if size.to_s == 'square'

    "#{base_url}/#{directory}/#{id}#{extension}"
  end

  def download_images(url, size, path)
    begin
      download = URI.parse(url).open
      download_URI = "#{path}/#{download.base_uri.to_s.split('/')[-1]}"
      if File.exist?(download_URI)
        puts "\tSkipping #{size}\t#{url}"
      else
        puts "\tDownloading #{size}\t#{url}..."
        IO.copy_stream(download, "#{path}/#{download.base_uri.to_s.split('/')[-1]}")
      end
    rescue OpenURI::HTTPError
      puts "\t404 returned\t#{url}"
    end
  end

  def download_chara_images(id)
    sizes = %w[main grid square]

    url = {
      'main': build_chara_url(id, 'main'),
      'grid': build_chara_url(id, 'grid'),
      'square': build_chara_url(id, 'square')
    }

    puts "Character #{id}"
    sizes.each do |size|
      path = "#{Rails.root}/download/character-#{size}"
      download_images(url[size.to_sym], size, path)
    end
  end

  def download_weapon_images(id)
    sizes = %w[main grid square]

    url = {
      'main': build_weapon_url(id, 'main'),
      'grid': build_weapon_url(id, 'grid'),
      'square': build_weapon_url(id, 'square')
    }

    puts "Weapon #{id}"
    sizes.each do |size|
      path = "#{Rails.root}/download/weapon-#{size}"
      download_images(url[size.to_sym], size, path)
    end
  end

  def download_summon_images(id)
    sizes = %w[main grid square]

    url = {
      'main': build_summon_url(id, 'main'),
      'grid': build_summon_url(id, 'grid'),
      'square': build_summon_url(id, 'square')
    }

    puts "Summon #{id}"
    sizes.each do |size|
      path = "#{Rails.root}/download/summon-#{size}"
      download_images(url[size.to_sym], size, path)
    end
  end

  desc 'Downloads images for the given Granblue_IDs'
  task :download_images, %i[object] => :environment do |_t, args|
    object = args[:object]
    list = args.extras

    list.each do |id|
      if object == 'character'
        download_chara_images("#{id}_01")
        download_chara_images("#{id}_02")
        download_chara_images("#{id}_03")
        download_chara_images("#{id}_04")
      elsif object == 'weapon'
        download_weapon_images(id)
      elsif object == 'summon'
        download_summon_images(id)
      end
    end
  end
end
