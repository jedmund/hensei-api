namespace :granblue do
  namespace :export do
    def build_summon_url(id, size)
      # Set up URL
      base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/summon'
      extension = '.jpg'

      directory = 'party_main' if size.to_s == 'main'
      directory = 'party_sub' if size.to_s == 'grid'
      directory = 's' if size.to_s == 'square'

      "#{base_url}/#{directory}/#{id}#{extension}"
    end

    desc 'Exports a list of summon URLs for a given size'
    task :summon, [:size] => :environment do |_t, args|
      # Set up options
      size = args[:size]

      # Include character model
      Dir.glob("#{Rails.root}/app/models/summon.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      unless File.exist?("#{dir}/summon-#{size}.txt")
        File.open("#{dir}/summon-#{size}.txt", 'w') do |f|
          Summon.all.each do |s|
            f.write("#{build_summon_url("#{s.granblue_id}_01", size)} \n")
            f.write("#{build_summon_url("#{s.granblue_id}_02", size)} \n") if (s.series == 3 || s.series == 0) && s.ulb
          end
        end
      end

      puts "Wrote #{Summon.count} summon URLs for \"#{size}\" size"
    end
  end
end
