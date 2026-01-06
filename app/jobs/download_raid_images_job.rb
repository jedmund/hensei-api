# frozen_string_literal: true

# Background job for downloading raid images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadRaidImagesJob.perform_later(raid.id)
#   # Poll status with: DownloadRaidImagesJob.status(raid.id)
class DownloadRaidImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    raid_id = job.arguments.first
    Rails.logger.error "[DownloadRaidImages] Raid #{raid_id} not found"
    update_status(raid_id, 'failed', error: 'Raid not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'raid_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for a raid
    #
    # @param raid_id [String] UUID of the raid
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :images_total, :error
    def status(raid_id)
      data = redis.get(redis_key(raid_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(raid_id)
      "#{REDIS_KEY_PREFIX}:#{raid_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(raid_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(raid_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(raid_id, force: false, size: 'all')
    Rails.logger.info "[DownloadRaidImages] Starting download for raid #{raid_id}"

    raid = Raid.find(raid_id)
    update_status(raid_id, 'processing', progress: 0, images_downloaded: 0)

    service = RaidImageDownloadService.new(
      raid,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadRaidImages] Completed for raid #{raid_id}"
      update_status(
        raid_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadRaidImages] Failed for raid #{raid_id}: #{result.error}"
      update_status(raid_id, 'failed', error: result.error)
      raise StandardError, result.error # Trigger retry
    end
  end

  private

  def update_status(raid_id, status, **attrs)
    self.class.update_status(raid_id, status, **attrs)
  end
end
