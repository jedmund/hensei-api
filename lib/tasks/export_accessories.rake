namespace :granblue do
  namespace :export do
    def build_url(id, type, size)
      # Set up URL
      base_url = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets'
      extension = '.jpg'

      directory = 'm' if size.to_s == 'grid'
      directory = 's' if size.to_s == 'square'

      "#{base_url}/#{type}/#{directory}/#{id}#{extension}"
    end

    desc 'Exports a list of accessories for a given size'
    task :accessory, [:size] => :environment do |_t, args|
      # Set up options
      size = args[:size]

      Dir.glob("#{Rails.root}/app/models/job_accessory.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      filename = "#{dir}/accessory-#{size}.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w') do |f|
        JobAccessory.all.each do |w|
          if w.accessory_type === 1
            f.write("#{build_url(w.granblue_id.to_s, "shield", size)} \n")
          elsif w.accessory_type === 2
            f.write("#{build_url(w.granblue_id.to_s, "familiar", size)} \n")
          end
        end
      end

      # CLI output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} job accessory URLs for \"#{size}\" size"
    end
  end
end
