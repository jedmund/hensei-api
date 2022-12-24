namespace :granblue do
  namespace :export do
    def build_weapon_url(id, size)
      # Set up URL
      base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/weapon'
      extension = '.jpg'

      directory = 'ls' if size.to_s == 'main'
      directory = 'm' if size.to_s == 'grid'
      directory = 's' if size.to_s == 'square'

      "#{base_url}/#{directory}/#{id}#{extension}"
    end

    desc 'Exports a list of weapon URLs for a given size'
    task :weapon, [:size] => :environment do |_t, args|
      # Set up options
      size = args[:size]

      # Include weapon model
      Dir.glob("#{Rails.root}/app/models/weapon.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      filename = "#{dir}/weapon-#{size}.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w') do |f|
        Weapon.all.each do |w|
          f.write("#{build_weapon_url(w.granblue_id.to_s, size)} \n")
        end
      end

      # CLI output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} weapon URLs for \"#{size}\" size"
    end
  end
end
