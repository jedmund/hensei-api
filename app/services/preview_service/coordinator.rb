# app/services/preview/coordinator.rb
module PreviewService
  class Coordinator
    PREVIEW_FOLDER = 'previews'
    PREVIEW_WIDTH = 1200
    PREVIEW_HEIGHT = 630
    PREVIEW_EXPIRY = 30.days
    GENERATION_TIMEOUT = 5.minutes
    LOCAL_STORAGE_PATH = Rails.root.join('storage', 'party-previews')
    PREVIEW_DEBOUNCE_PERIOD = 5.minutes

    # Public Interface - Core Operations

    # Initialize the party preview service
    #
    # @param party [Party] The party to generate a preview for
    def initialize(party)
      @party = party
      @image_fetcher = ImageFetcherService.new(AwsService.new)
      @grid_service = Grid.new
      @canvas_service = Canvas.new(@image_fetcher)
      setup_storage
    end

    # Retrieves the URL for the party's preview image
    #
    # @return [String] A URL pointing to the party's preview image
    def preview_url
      if preview_exists?
        Rails.env.production? ? generate_s3_url : local_preview_url
      else
        schedule_generation unless generation_in_progress?
        default_preview_url
      end
    end

    # Generates a preview image for the party
    #
    # @return [Boolean] True if preview generation was successful, false otherwise
    def generate_preview
      return false unless should_generate?

      begin
        Rails.logger.info("🖼️ Starting preview generation for party #{@party.id}")

        Rails.logger.info("🖼️ Updating party state to in_progress")
        @party.update!(preview_state: :in_progress)
        set_generation_in_progress

        Rails.logger.info("🖼️ Checking ImageMagick installation...")
        begin
          version = `convert -version`
          Rails.logger.info("🖼️ ImageMagick version: #{version}")
        rescue => e
          Rails.logger.error("🖼️ Failed to get ImageMagick version: #{e.message}")
        end

        Rails.logger.info("🖼️ Creating preview image...")
        begin
          image = create_preview_image
          Rails.logger.info("🖼️ Preview image created successfully")
        rescue => e
          Rails.logger.error("🖼️ Failed to create preview image: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise e
        end

        Rails.logger.info("🖼️ Saving preview...")
        begin
          save_preview(image)
          Rails.logger.info("🖼️ Preview saved successfully")
        rescue => e
          Rails.logger.error("🖼️ Failed to save preview: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          raise e
        end

        Rails.logger.info("🖼️ Updating party state...")
        @party.update!(
          preview_state: :generated,
          preview_generated_at: Time.current
        )
        Rails.logger.info("🖼️ Party state updated successfully")

        true
      rescue => e
        Rails.logger.error("🖼️ Preview generation failed: #{e.class} - #{e.message}")
        Rails.logger.error("🖼️ Stack trace:")
        Rails.logger.error(e.backtrace.join("\n"))
        handle_preview_generation_error(e)
        false
      ensure
        Rails.logger.info("🖼️ Cleaning up resources...")
        @image_fetcher.cleanup
        clear_generation_in_progress
        Rails.logger.info("🖼️ Cleanup completed")
      end
    end

    # Forces regeneration of the party's preview image
    #
    # @return [Boolean] Result of the preview generation attempt
    def force_regenerate
      delete_preview if preview_exists?
      generate_preview
    end

    # Deletes the existing preview image for the party
    #
    # @return [void]
    def delete_preview
      if Rails.env.production?
        delete_s3_preview
      else
        delete_local_previews
      end

      @party.update!(
        preview_state: :pending,
        preview_generated_at: nil
      )
    rescue => e
      Rails.logger.error("Failed to delete preview for party #{@party.id}: #{e.message}")
    end

    # State Management - Public

    # Determines if a new preview should be generated
    #
    # @return [Boolean] True if a new preview should be generated, false otherwise
    def should_generate?
      Rails.logger.info("🖼️ Checking should_generate? conditions")

      unless @party.ready_for_preview?
        Rails.logger.info("🖼️ Party not ready for preview (insufficient content)")
        return false
      end

      if generation_in_progress?
        Rails.logger.info("🖼️ Generation already in progress, returning false")
        return false
      end

      Rails.logger.info("🖼️ Preview state: #{@party.preview_state}")

      case @party.preview_state
      when 'pending', 'queued'
        Rails.logger.info("🖼️ State is #{@party.preview_state}, will generate")
        true
      when 'in_progress'
        Rails.logger.info("🖼️ State is in_progress, skipping generation")
        false
      when 'failed'
        should_retry = @party.preview_generated_at.nil? ||
          @party.preview_generated_at < PREVIEW_DEBOUNCE_PERIOD.ago
        Rails.logger.info("🖼️ Failed state, should retry: #{should_retry}")
        should_retry
      when 'generated'
        expired = @party.preview_expired?
        changed = @party.preview_content_changed?
        debounced = @party.preview_generated_at.nil? ||
          @party.preview_generated_at < PREVIEW_DEBOUNCE_PERIOD.ago

        should_regenerate = expired || (changed && debounced)

        Rails.logger.info("🖼️ Generated state check - expired: #{expired}, content changed: #{changed}, debounced: #{debounced}")
        Rails.logger.info("🖼️ Should regenerate: #{should_regenerate}")

        should_regenerate
      else
        Rails.logger.info("🖼️ Unknown state, will generate")
        true
      end
    end

    # Checks if a preview generation is currently in progress
    #
    # @return [Boolean] True if a preview is being generated, false otherwise
    def generation_in_progress?
      in_progress = Rails.cache.exist?("party_preview_generating_#{@party.id}")
      Rails.logger.info("Cache key check for generation_in_progress: #{in_progress}")
      in_progress
    end

    # Retrieves the S3 object for the party's preview image
    #
    # @return [Aws::S3::Types::GetObjectOutput] S3 object containing the preview image
    # @raise [Aws::S3::Errors::NoSuchKey] If the preview image doesn't exist in S3
    # @raise [Aws::S3::Errors::NoSuchBucket] If the configured bucket doesn't exist
    def get_s3_object
      @aws_service.s3_client.get_object(
        bucket: @aws_service.bucket,
        key: preview_key
      )
    end

    # Schedules a background job to generate the preview
    #
    # @return [void]
    def schedule_generation
      GeneratePartyPreviewJob
        .set(wait: 30.seconds)
        .perform_later(@party.id)

      @party.update!(preview_state: :queued)
    end

    # Returns the full path for storing preview images locally
    #
    # @return [Pathname] Full path where the preview image should be stored
    def local_preview_path
      LOCAL_STORAGE_PATH.join(preview_filename)
    end

    # Creates the preview image for the party
    #
    # @return [MiniMagick::Image] The generated preview image
    def create_preview_image
      Rails.logger.info("Creating blank canvas...")
      begin
        canvas = @canvas_service.create_blank_canvas
        Rails.logger.info("Canvas created at: #{canvas.path}")
        image = MiniMagick::Image.new(canvas.path)
        Rails.logger.info("MiniMagick image object created")
      rescue => e
        Rails.logger.error("Failed to create canvas: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise e
      end

      # Add more detailed logging for job icon handling
      Rails.logger.info("Processing job icon...")
      job_icon = nil
      if @party.job.present?
        Rails.logger.info("Job present: #{@party.job.inspect}")
        Rails.logger.info("Fetching job icon for job ID: #{@party.job.granblue_id}")
        begin
          job_icon = @image_fetcher.fetch_job_icon(@party.job.granblue_id)
          Rails.logger.info("Job icon fetched successfully") if job_icon
        rescue => e
          Rails.logger.error("Failed to fetch job icon: #{e.class} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          # Don't raise this error, just log it and continue without the job icon
        end
      end

      begin
        Rails.logger.info("Adding party name and job icon...")
        text_result = @canvas_service.add_text(image, @party.name, job_icon: job_icon, user: @party.user)
        image = text_result[:image]
        Rails.logger.info("Text and icon added successfully")
      rescue => e
        Rails.logger.error("Failed to add text/icon: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise e
      end

      begin
        Rails.logger.info("Calculating grid layout...")
        grid_layout = @grid_service.calculate_layout(
          canvas_height: Canvas::PREVIEW_HEIGHT,
          title_bottom_y: text_result[:text_bottom_y]
        )
        Rails.logger.info("Grid layout calculated")

        Rails.logger.info("Drawing weapons...")
        Rails.logger.info("Weapons count: #{@party.weapons.count}")
        image = organize_and_draw_weapons(image, grid_layout)
        Rails.logger.info("Weapons drawn successfully")
      rescue => e
        Rails.logger.error("Failed during weapons drawing: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        raise e
      end

      image
    end

    private

    # Sets up the appropriate storage system based on environment
    #
    # @return [void]
    def setup_storage
      # Always initialize AWS service for potential image fetching
      @aws_service = AwsService.new

      # Create local storage paths in development
      FileUtils.mkdir_p(LOCAL_STORAGE_PATH) unless Dir.exist?(LOCAL_STORAGE_PATH.to_s)
    end

    # Image Generation Pipeline

    # Adds the job icon to the preview image
    #
    # @param image [MiniMagick::Image] The base image
    # @param job_icon [MiniMagick::Image] The job icon to add
    # @return [MiniMagick::Image] The updated image
    def add_job_icon(image, job_icon)
      job_icon.resize '200x200'
      image.composite(job_icon) do |comp|
        comp.compose "Over"
        comp.geometry "+40+120"
      end
    end

    # Organizes and draws weapons on the preview image
    #
    # @param image [MiniMagick::Image] The base image
    # @param grid_layout [Hash] The layout configuration for the grid
    # @return [MiniMagick::Image] The updated image with weapons
    def organize_and_draw_weapons(image, grid_layout)
      mainhand_weapon = @party.weapons.find(&:mainhand)
      grid_weapons = @party.weapons.reject(&:mainhand)

      # Draw mainhand weapon
      if mainhand_weapon
        weapon_image = @image_fetcher.fetch_weapon_image(mainhand_weapon.weapon, mainhand: true)
        image = @grid_service.draw_grid_item(image, weapon_image, 'mainhand', 0, grid_layout) if weapon_image
      end

      # Draw grid weapons
      grid_weapons.each_with_index do |weapon, idx|
        weapon_image = @image_fetcher.fetch_weapon_image(weapon.weapon)
        image = @grid_service.draw_grid_item(image, weapon_image, 'weapon', idx, grid_layout) if weapon_image
      end

      image
    end

    # Draws the mainhand weapon on the preview image
    #
    # @param image [MiniMagick::Image] The base image
    # @param weapon_image [MiniMagick::Image] The weapon image to add
    # @return [MiniMagick::Image] The updated image
    def draw_mainhand_weapon(image, weapon_image)
      target_size = Grid::GRID_CELL_SIZE * 1.5
      weapon_image.resize "#{target_size}x#{target_size}"

      image.composite(weapon_image) do |c|
        c.compose "Over"
        c.gravity "northwest"
        c.geometry "+150+150"
      end
    end

    # Storage Operations

    # Saves the preview image to the appropriate storage system
    #
    # @param image [MiniMagick::Image] The image to save
    # @return [void]
    def save_preview(image)
      if Rails.env.production?
        upload_to_s3(image)
      else
        save_to_local_storage(image)
      end
    end

    # Uploads the preview image to S3
    #
    # @param image [MiniMagick::Image] The image to upload
    # @return [void]
    def upload_to_s3(image)
      temp_file = Tempfile.new(%w[preview .png])
      begin
        image.write(temp_file.path)

        # Use fixed key without timestamp
        key = "#{PREVIEW_FOLDER}/#{@party.shortcode}.png"

        File.open(temp_file.path, 'rb') do |file|
          @aws_service.s3_client.put_object(
            bucket: @aws_service.bucket,
            key: key,
            body: file,
            content_type: 'image/png',
            acl: 'private'
          )
        end

        @party.update!(preview_s3_key: key)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # Saves the preview image to local storage
    #
    # @param image [MiniMagick::Image] The image to save
    # @return [void]
    def save_to_local_storage(image)
      image.write(local_preview_path)
    end

    # Path & URL Generation

    # Generates a filename for the preview image
    #
    # @return [String] Filename for the preview image
    def preview_filename
      "#{@party.shortcode}.png"
    end

    # Returns the URL for accessing locally stored preview images
    #
    # @return [String] URL path to access the preview image in development
    def local_preview_url
      latest_preview = Dir.glob(LOCAL_STORAGE_PATH.join("#{@party.shortcode}_*.png").to_s)
                          .max_by { |f| File.mtime(f) }
      return default_preview_url unless latest_preview

      "/party-previews/#{File.basename(latest_preview)}"
    end

    # Generates the S3 key for the party's preview image
    #
    # @return [String] The S3 object key for the preview image
    def preview_key
      "#{PREVIEW_FOLDER}/#{@party.shortcode}.png"
    end

    # Preview State Management

    # Checks if a preview image exists for the party
    #
    # @return [Boolean] True if a preview exists, false otherwise
    def preview_exists?
      return false unless @party.preview_state == 'generated'

      if Rails.env.production?
        @aws_service.file_exists?(preview_key)
      else
        !Dir.glob(LOCAL_STORAGE_PATH.join("#{@party.shortcode}.png").to_s).empty?
      end
    rescue Aws::S3::Errors::NotFound
      false
    end

    # Generates a pre-signed S3 URL for the preview image
    #
    # @return [String] A pre-signed URL to access the preview image
    def generate_s3_url
      signer = Aws::S3::Presigner.new(client: @aws_service.s3_client)
      signer.presigned_url(
        :get_object,
        bucket: @aws_service.bucket,
        key: preview_key,
        expires_in: 1.hour.to_i
      )
    end

    # Marks the preview generation as in progress
    #
    # @return [void]
    def set_generation_in_progress
      Rails.cache.write(
        "party_preview_generating_#{@party.id}",
        true,
        expires_in: GENERATION_TIMEOUT
      )
    end

    # Clears the in-progress flag for preview generation
    #
    # @return [void]
    def clear_generation_in_progress
      Rails.cache.delete("party_preview_generating_#{@party.id}")
    end

    # Job Scheduling

    # URL Generation

    # Provides a default preview URL based on party attributes
    #
    # @return [String] A URL to a default preview image
    def default_preview_url
      if @party.element.present?
        "/default-previews/#{@party.element}.png"
      else
        "/default-previews/default.png"
      end
    end

    # Cleanup Operations

    # Deletes the preview from S3
    #
    # @return [void]
    def delete_s3_preview
      @aws_service.s3_client.delete_object(
        bucket: @aws_service.bucket,
        key: preview_key
      )
    end

    def self.cleanup_stalled_jobs
      Party.where(preview_state: :in_progress)
           .where('updated_at < ?', 10.minutes.ago)
           .update_all(preview_state: :pending)
    end

    # Deletes local preview files
    #
    # @return [void]
    def delete_local_previews
      Dir.glob(LOCAL_STORAGE_PATH.join("#{@party.shortcode}_*.png").to_s).each do |file|
        File.delete(file)
      end
    end

    # Error Handling

    # Handles errors during preview generation
    #
    # @param error [Exception] The error that occurred
    # @return [void]
    def handle_preview_generation_error(error)
      Rails.logger.error("Preview generation failed for party #{@party.id}")
      Rails.logger.error("Error: #{error.class} - #{error.message}")
      Rails.logger.error(error.backtrace.join("\n"))

      @party.update_columns(
        preview_state: 'failed',
        preview_generated_at: Time.current
      )
    end
  end
end
