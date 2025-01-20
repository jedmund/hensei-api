# app/services/canvas.rb
module PreviewService
  class Canvas
    PREVIEW_WIDTH = 1200
    PREVIEW_HEIGHT = 630
    DEFAULT_BACKGROUND_COLOR = '#1a1b1e'

    # Padding and spacing constants
    PADDING = 24
    TITLE_IMAGE_GAP = 24
    GRID_GAP = 4

    def initialize(image_fetcher)
      @image_fetcher = image_fetcher
    end

    def create_blank_canvas(width: PREVIEW_WIDTH, height: PREVIEW_HEIGHT, color: DEFAULT_BACKGROUND_COLOR)
      Rails.logger.info("Creating blank canvas #{width}x#{height}")
      temp_file = Tempfile.new(%w[canvas .png])
      Rails.logger.info("Temp file created at: #{temp_file.path}")

      begin
        Rails.logger.info("Checking ImageMagick setup...")
        version = `which convert`
        Rails.logger.info("ImageMagick convert path: #{version}")

        Rails.logger.info("Executing convert command...")
        MiniMagick::Tool::Convert.new do |convert|
          convert.size "#{width}x#{height}"
          convert << "xc:#{color}"
          convert << temp_file.path
        end
        Rails.logger.info("Convert command completed successfully")
      rescue => e
        Rails.logger.error("Failed to create canvas with convert: #{e.class} - #{e.message}")
        Rails.logger.error("PATH: #{ENV['PATH']}")
        Rails.logger.error("LD_LIBRARY_PATH: #{ENV['LD_LIBRARY_PATH']}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise
      end

      Rails.logger.info("Canvas created successfully at: #{temp_file.path}")
      temp_file
    end

    def add_text(image, party_name, job_icon: nil, user: nil, **options)
      party_name = party_name.to_s.strip
      party_name = 'Untitled' if party_name.empty?

      font_size = options.fetch(:size, '32')
      font_color = options.fetch(:color, 'white')

      # Try multiple font locations
      font_locations = [
        Rails.root.join('app', 'assets', 'fonts', 'Gk-Bd.otf').to_s,
        Rails.root.join('public', 'assets', 'fonts', 'Gk-Bd.otf').to_s
      ]

      @font_path = font_locations.find { |path| File.exist?(path) }

      unless @font_path
        Rails.logger.error("Font file not found in any location: #{font_locations.join(', ')}")
        raise "Font file not found"
      end

      Rails.logger.info("Using font path: #{@font_path}")
      unless File.exist?(@font_path)
        Rails.logger.error("Font file not found at: #{@font_path}")
        raise "Font file not found"
      end

      # Measure party name text size
      text_metrics = measure_text(party_name, font_size)

      # Draw job icon if provided
      image = draw_job_icon(image, job_icon) if job_icon

      # Draw party name text
      image = draw_party_name(image, party_name, text_metrics, job_icon, font_color, font_size)

      # Compute vertical center of the party name text line
      party_text_center_y = PADDING + (text_metrics[:height] / 2.0)

      # Draw user info if provided
      image = draw_user_info(image, user, party_text_center_y, font_color) if user

      {
        image: image,
        text_bottom_y: PADDING + text_metrics[:height] + TITLE_IMAGE_GAP
      }
    end

    private

    def draw_job_icon(image, job_icon)
      job_icon.format("png32")
      job_icon.alpha('set')
      job_icon.background('none')
      job_icon.combine_options do |c|
        c.filter "Lanczos" # High-quality filter
        c.resize "64x64"
      end
      image = image.composite(job_icon) do |c|
        c.compose "Over"
        c.geometry "+#{PADDING}+#{PADDING}"
      end
      image
    end

    def draw_party_name(image, party_name, text_metrics, job_icon, font_color, font_size)
      text_x = job_icon ? PADDING + 64 + 16 : PADDING
      text_y = PADDING + text_metrics[:height]

      image.combine_options do |c|
        c.gravity 'NorthWest'
        c.fill font_color
        c.font @font_path
        c.pointsize font_size
        # Escape quotes and use pango markup for better text handling
        c.annotate "0x0+#{text_x}+#{text_y}", party_name.gsub('"', '\"')
      end

      image
    end

    def draw_user_info(image, user, party_text_center_y, font_color)
      username_font_size = 24
      username_font_path = @font_path

      # Fetch and prepare user picture
      user_picture = @image_fetcher.fetch_user_picture(user.picture)
      if user_picture
        user_picture.format("png32")
        user_picture.alpha('set')
        user_picture.background('none')
        user_picture.combine_options do |c|
          c.filter "Lanczos" # Use a high-quality filter
          c.resize "48x48"
        end
      end

      # Measure username text size
      username_metrics = measure_text(user.username, username_font_size, font: username_font_path)

      right_padding = PADDING
      total_user_width = 48 + 8 + username_metrics[:width]
      user_x = image.width - right_padding - total_user_width

      # Center user picture vertically relative to party text line
      user_pic_y = (party_text_center_y - (48 / 2.0)).round

      image = image.composite(user_picture) do |c|
        c.compose "Over"
        c.geometry "+#{user_x}+#{user_pic_y}"
      end if user_picture

      # Adjust text y-coordinate to better align vertically with the picture
      # You may need to tweak the offset value based on visual inspection.
      vertical_offset = 6 # Adjust this value as needed
      user_text_y = (party_text_center_y + (username_metrics[:height] / 2.0) - vertical_offset).round

      image.combine_options do |c|
        c.font username_font_path
        c.fill font_color
        c.pointsize username_font_size
        text_x = user_x + 48 + 12
        c.draw "text #{text_x},#{user_text_y} '#{user.username}'"
      end

      image
    end

    def measure_text(text, font_size, font: @font_path)
      # Ensure text is not empty and is properly escaped
      text = text.to_s.strip
      text = 'Untitled' if text.empty?

      # Escape text for shell command
      escaped_text = text.gsub(/'/, "'\\\\''")

      # Create a temporary file for the text measurement
      temp_file = Tempfile.new(['text_measure', '.png'])

      begin
        # Use ImageMagick command to create an image with the text
        command = [
          'magick',
          '-background', 'transparent',
          '-fill', 'black',
          '-font', font,
          '-pointsize', font_size.to_s,
          "label:'#{escaped_text}'", # Quote the text
          temp_file.path
        ]

        # Execute the command
        system(*command)

        # Use MiniMagick to read the image and get dimensions
        image = MiniMagick::Image.open(temp_file.path)

        {
          height: image.height,
          width: image.width
        }
      rescue => e
        Rails.logger.error "Text measurement error: #{e.message}"
        # Fallback dimensions
        { height: 50, width: 200 }
      ensure
        # Close and unlink the temporary file
        temp_file.close
        temp_file.unlink
      end
    end
  end
end
