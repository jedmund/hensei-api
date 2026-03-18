# frozen_string_literal: true

# Background job for downloading job accessory images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadJobAccessoryImagesJob.perform_later(accessory.id)
#   # Poll status with: DownloadJobAccessoryImagesJob.status(accessory.id)
class DownloadJobAccessoryImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    accessory_id = job.arguments.first
    Rails.logger.error "[DownloadJobAccessoryImages] JobAccessory #{accessory_id} not found"
    update_status(accessory_id, 'failed', error: 'Job accessory not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'job_accessory_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for an accessory
    #
    # @param accessory_id [String] UUID of the job accessory
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :error
    def status(accessory_id)
      data = redis.get(redis_key(accessory_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(accessory_id)
      "#{REDIS_KEY_PREFIX}:#{accessory_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(accessory_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(accessory_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(accessory_id, force: false, size: 'all')
    Rails.logger.info "[DownloadJobAccessoryImages] Starting download for accessory #{accessory_id} " \
                      "(force=#{force}, size=#{size})"

    accessory = JobAccessory.find(accessory_id)
    Rails.logger.info "[DownloadJobAccessoryImages] Found accessory: #{accessory.granblue_id} " \
                      "(accessory_type=#{accessory.accessory_type})"
    update_status(accessory_id, 'processing', progress: 0, images_downloaded: 0)

    selected_size = size == 'all' ? nil : size

    begin
      downloader = Granblue::Downloaders::JobAccessoryDownloader.new(
        accessory.granblue_id,
        storage: :s3,
        force: force,
        verbose: true
      )
      downloader.download(selected_size)

      downloaded_count = selected_size ? 1 : 2
      Rails.logger.info "[DownloadJobAccessoryImages] Completed for accessory #{accessory_id}: #{downloaded_count} images"
      update_status(
        accessory_id,
        'completed',
        progress: 100,
        images_downloaded: downloaded_count,
        images_total: downloaded_count
      )
    rescue StandardError => e
      Rails.logger.error "[DownloadJobAccessoryImages] Failed for accessory #{accessory_id}: #{e.message}"
      update_status(accessory_id, 'failed', error: e.message)
      raise
    end
  end

  private

  def update_status(accessory_id, status, **attrs)
    self.class.update_status(accessory_id, status, **attrs)
  end
end
