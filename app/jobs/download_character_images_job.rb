# frozen_string_literal: true

# Background job for downloading character images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadCharacterImagesJob.perform_later(character.id)
#   # Poll status with: DownloadCharacterImagesJob.status(character.id)
class DownloadCharacterImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    character_id = job.arguments.first
    Rails.logger.error "[DownloadCharacterImages] Character #{character_id} not found"
    update_status(character_id, 'failed', error: 'Character not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'character_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for a character
    #
    # @param character_id [String] UUID of the character
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :images_total, :error
    def status(character_id)
      data = redis.get(redis_key(character_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(character_id)
      "#{REDIS_KEY_PREFIX}:#{character_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(character_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(character_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(character_id, force: false, size: 'all')
    Rails.logger.info "[DownloadCharacterImages] Starting download for character #{character_id}"

    character = Character.find(character_id)
    update_status(character_id, 'processing', progress: 0, images_downloaded: 0)

    service = CharacterImageDownloadService.new(
      character,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadCharacterImages] Completed for character #{character_id}"
      update_status(
        character_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadCharacterImages] Failed for character #{character_id}: #{result.error}"
      update_status(character_id, 'failed', error: result.error)
      raise StandardError, result.error # Trigger retry
    end
  end

  private

  def update_status(character_id, status, **attrs)
    self.class.update_status(character_id, status, **attrs)
  end
end
