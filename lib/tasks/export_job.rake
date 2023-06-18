namespace :granblue do
  namespace :export do
    def build_job_icon_url(id)
      base_url = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/ui/icon/job'
      extension = '.png'

      "#{base_url}/#{id}#{extension}"
    end

    def build_job_portrait_url(id, proficiency, gender)
      base_url = 'https://prd-game-a1-granbluefantasy.akamaized.net/assets_en/img/sp/assets/leader/quest'
      extension = '.jpg'

      prefix = ""
      case proficiency
      when 1
        prefix = "sw"
      when 2
        prefix = "kn"
      when 3
        prefix = "ax"
      when 4
        prefix = "sp"
      when 5
        prefix = "bw"
      when 6
        prefix = "wa"
      when 7
        prefix = "me"
      when 8
        prefix = "mc"
      when 9
        prefix = "gu"
      when 10
        prefix = "kt"
      end

      "#{base_url}/#{id}_#{prefix}_#{gender}_01#{extension}"
    end

    # job-icon
    def write_urls(size)
      # Include model
      Dir.glob("#{Rails.root}/app/models/job.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      filename = "#{dir}job-#{size}.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w') do |f|
        Job.all.each do |w|
          if size == 'icon'
            f.write("#{build_job_icon_url(w.granblue_id.to_s)} \n")
          elsif size == 'portrait'
            f.write("#{build_job_portrait_url(w.granblue_id.to_s, w.proficiency1, 0)} \n")
            f.write("#{build_job_portrait_url(w.granblue_id.to_s, w.proficiency1, 1)} \n")
          end
        end
      end

      # CLI output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} job URLs for #{size} size"
    end

    desc 'Exports a list of job URLs for a given size'
    task :job, [:size] => :environment do |_t, args|
      write_urls(args[:size])
    end
  end
end
