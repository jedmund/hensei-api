namespace :granblue do
  namespace :export do
    def build_chara_url(id, size)
      # Set up URL
      base_url = 'http://gbf.game-a.mbga.jp/assets/img/sp/assets/npc'
      extension = '.jpg'

      directory = 'f' if size.to_s == 'main'
      directory = 'm' if size.to_s == 'grid'
      directory = 's' if size.to_s == 'square'

      "#{base_url}/#{directory}/#{id}#{extension}"
    end

    desc 'Exports a list of character URLs for a given size'
    task :character, [:size] => :environment do |_t, args|
      # Set up options
      size = args[:size]

      # Include character model
      Dir.glob("#{Rails.root}/app/models/character.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      filename = "#{dir}/character-#{size}.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w+') do |f|
        Character.all.each do |c|
          f.write("#{build_chara_url("#{c.granblue_id}_01", size)} \n")
          f.write("#{build_chara_url("#{c.granblue_id}_02", size)} \n")
          f.write("#{build_chara_url("#{c.granblue_id}_03", size)} \n") if c.flb
          f.write("#{build_chara_url("#{c.granblue_id}_04", size)} \n") if c.ulb
        end
      end

      # CLI Output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} character URLs for \"#{size}\" size"
    end
  end
end
