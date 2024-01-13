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
      filename = "#{dir}/summon-#{size}.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w') do |f|
        Summon.all.each do |s|
          series = s.series.to_i
          f.write("#{build_summon_url(s.granblue_id.to_s, size)} \n")

          # Download second images only for Providence ULBs and Primal summons
          if series == 3 || (series == 0 && s.ulb)
            f.write("#{build_summon_url("#{s.granblue_id}_02",
                                        size)} \n")
          end

          if s.transcendence
            f.write("#{build_summon_url("#{s.granblue_id}_03",
                                        size)} \n")
          end
        end
      end

      # CLI output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} summon URLs for \"#{size}\" size"
    end
  end
end
