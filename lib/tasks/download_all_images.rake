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

  desc 'Downloads images for the given object type at the given size'
  task :download_all_images, %i[object size] => :environment do |_t, args|
    require 'open-uri'

    filename = "export/#{args[:object]}-#{args[:size]}.txt"
    count = `wc -l #{filename}`.split.first.to_i

    path = "#{Rails.root}/download/#{args[:object]}-#{args[:size]}"
    FileUtils.mkdir_p(path) unless Dir.exist?(path)

    puts "Downloading #{count} images from #{args[:object]}-#{args[:size]}.txt..."
    if File.exist?(filename)
      File.readlines(filename).each_with_index do |line, i|
        download = URI.parse(line.strip).open
        download_URI = "#{path}/#{download.base_uri.to_s.split('/')[-1]}"
        if File.exist?(download_URI)
          puts "Skipping #{line}"
        else
          IO.copy_stream(download, "#{path}/#{download.base_uri.to_s.split('/')[-1]}")
          _progress_reporter(count: i, total: count, result: download_URI, bar_len: 40, multi: false)
        end
      rescue StandardError => e
        puts "#{e}: #{line}"
      end
    end
  end
end
