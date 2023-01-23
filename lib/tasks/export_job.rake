namespace :granblue do
  namespace :export do
    def build_job_icon_url(id)
      # Set up URL
      base_url = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/ui/icon/job'
      extension = '.png'

      "#{base_url}/#{id}#{extension}"
    end

    desc 'Exports a list of weapon URLs for a given size'
    task :job do |_t, _args|
      # Include weapon model
      Dir.glob("#{Rails.root}/app/models/job.rb").each { |file| require file }

      # Set up filepath
      dir = "#{Rails.root}/export/"
      filename = "#{dir}/job-icon.txt"
      FileUtils.mkdir(dir) unless Dir.exist?(dir)

      # Write to file
      File.open(filename, 'w') do |f|
        Job.all.each do |w|
          f.write("#{build_job_icon_url(w.granblue_id.to_s)} \n")
        end
      end

      # CLI output
      count = `wc -l #{filename}`.split.first.to_i
      puts "Wrote #{count} job URLs for icon size"
    end
  end
end
