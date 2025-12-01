# frozen_string_literal: true

# Background job for downloading summon images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadSummonImagesJob.perform_later(summon.id)
#   # Poll status with: DownloadSummonImagesJob.status(summon.id)
class DownloadSummonImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    summon_id = job.arguments.first
    Rails.logger.error "[DownloadSummonImages] Summon #{summon_id} not found"
    update_status(summon_id, 'failed', error: 'Summon not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'summon_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for a summon
    #
    # @param summon_id [String] UUID of the summon
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :images_total, :error
    def status(summon_id)
      data = redis.get(redis_key(summon_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(summon_id)
      "#{REDIS_KEY_PREFIX}:#{summon_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(summon_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(summon_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(summon_id, force: false, size: 'all')
    Rails.logger.info "[DownloadSummonImages] Starting download for summon #{summon_id}"

    summon = Summon.find(summon_id)
    update_status(summon_id, 'processing', progress: 0, images_downloaded: 0)

    service = SummonImageDownloadService.new(
      summon,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadSummonImages] Completed for summon #{summon_id}"
      update_status(
        summon_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadSummonImages] Failed for summon #{summon_id}: #{result.error}"
      update_status(summon_id, 'failed', error: result.error)
      raise StandardError, result.error # Trigger retry
    end
  end

  private

  def update_status(summon_id, status, **attrs)
    self.class.update_status(summon_id, status, **attrs)
  end
end
