# app/services/image_fetcher_service.rb
module PreviewService
  class ImageFetcherService
    def initialize(aws_service)
      @aws_service = aws_service
      @tempfiles = []
    end

    def fetch_s3_image(key, folder = nil)
      full_key = folder ? "#{folder}/#{key}" : key
      temp_file = create_temp_file

      download_from_s3(full_key, temp_file)
      create_mini_magick_image(temp_file)
    rescue => e
      handle_fetch_error(e, full_key)
    end

    def fetch_job_icon(job_name)
      fetch_s3_image("#{job_name.downcase}.png", 'job-icons')
    end

    def fetch_weapon_image(weapon, mainhand: false)
      folder = mainhand ? 'weapon-main' : 'weapon-grid'
      fetch_s3_image("#{weapon.granblue_id}.jpg", folder)
    end

    def fetch_user_picture(picture_identifier)
      # Assuming user pictures are stored as PNG in a folder called 'user-pictures'
      fetch_s3_image("#{picture_identifier}.png", 'profile')
    end

    def cleanup
      @tempfiles.each do |tempfile|
        tempfile.close
        tempfile.unlink
      end
      @tempfiles.clear
    end

    private

    def create_temp_file
      temp_file = Tempfile.new(['image', '.jpg'])
      temp_file.binmode
      @tempfiles << temp_file
      temp_file
    end

    def download_from_s3(key, temp_file)
      response = @aws_service.s3_client.get_object(
        bucket: @aws_service.bucket,
        key: key
      )
      temp_file.write(response.body.read)
      temp_file.rewind
    end

    def create_mini_magick_image(temp_file)
      MiniMagick::Image.new(temp_file.path)
    end

    def handle_fetch_error(error, key)
      Rails.logger.error "Error fetching image #{key}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      nil
    end
  end
end
