# frozen_string_literal: true

class DownloadBulletImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    bullet_id = job.arguments.first
    Rails.logger.error "[DownloadBulletImages] Bullet #{bullet_id} not found"
    update_status(bullet_id, 'failed', error: 'Bullet not found')
  end

  REDIS_KEY_PREFIX = 'bullet_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    def status(bullet_id)
      data = redis.get(redis_key(bullet_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(bullet_id)
      "#{REDIS_KEY_PREFIX}:#{bullet_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(bullet_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(bullet_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(bullet_id, force: false, size: 'all')
    Rails.logger.info "[DownloadBulletImages] Starting download for bullet #{bullet_id}"

    bullet = Bullet.find(bullet_id)
    update_status(bullet_id, 'processing', progress: 0, images_downloaded: 0)

    service = BulletImageDownloadService.new(
      bullet,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadBulletImages] Completed for bullet #{bullet_id}"
      update_status(
        bullet_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadBulletImages] Failed for bullet #{bullet_id}: #{result.error}"
      update_status(bullet_id, 'failed', error: result.error)
      raise StandardError, result.error
    end
  end

  private

  def update_status(bullet_id, status, **attrs)
    self.class.update_status(bullet_id, status, **attrs)
  end
end
