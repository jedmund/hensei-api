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

    desc 'Download job images using the JobDownloader'
    task :job_images, [:id, :test_mode, :verbose, :storage, :size] => :environment do |_t, args|
      require 'granblue/downloaders/job_downloader'

      id = args[:id]
      test_mode = args[:test_mode] == 'true'
      verbose = args[:verbose] != 'false' # Default to true
      storage = (args[:storage] || 'both').to_sym
      size = args[:size]

      logger = Logger.new($stdout)

      if id
        # Download a specific job
        job = Job.find_by(granblue_id: id)
        if job
          logger.info "Downloading images for job: #{job.name_en} (#{job.granblue_id})"
          logger.info "Test mode: #{test_mode}" if test_mode
          logger.info "Storage: #{storage}"
          logger.info "Size: #{size}" if size

          downloader = Granblue::Downloaders::JobDownloader.new(
            job.granblue_id,
            test_mode: test_mode,
            verbose: verbose,
            storage: storage,
            logger: logger
          )
          downloader.download(size)
        else
          logger.error "Job not found with ID: #{id}"
          exit 1
        end
      else
        # Download all jobs
        jobs = Job.all.order(:granblue_id)
        total = jobs.count
        logger.info "Found #{total} jobs to process"
        logger.info "Test mode: #{test_mode}" if test_mode
        logger.info "Storage: #{storage}"
        logger.info "Size: #{size}" if size

        jobs.each_with_index do |job, index|
          logger.info "[#{index + 1}/#{total}] Processing: #{job.name_en} (#{job.granblue_id})"

          downloader = Granblue::Downloaders::JobDownloader.new(
            job.granblue_id,
            test_mode: test_mode,
            verbose: verbose,
            storage: storage,
            logger: logger
          )
          downloader.download(size)

          # Add a small delay to avoid hammering the server
          sleep(0.5) unless test_mode
        end
      end

      logger.info "Job image download completed!"
    end
  end
end
