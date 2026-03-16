# frozen_string_literal: true

# Background job for downloading weapon images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadWeaponImagesJob.perform_later(weapon.id)
#   # Poll status with: DownloadWeaponImagesJob.status(weapon.id)
class DownloadWeaponImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    weapon_id = job.arguments.first
    Rails.logger.error "[DownloadWeaponImages] Weapon #{weapon_id} not found"
    update_status(weapon_id, 'failed', error: 'Weapon not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'weapon_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for a weapon
    #
    # @param weapon_id [String] UUID of the weapon
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :images_total, :error
    def status(weapon_id)
      data = redis.get(redis_key(weapon_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(weapon_id)
      "#{REDIS_KEY_PREFIX}:#{weapon_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(weapon_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(weapon_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(weapon_id, force: false, size: 'all')
    Rails.logger.info "[DownloadWeaponImages] Starting download for weapon #{weapon_id} " \
                      "(force=#{force}, size=#{size})"

    weapon = Weapon.find(weapon_id)
    Rails.logger.info "[DownloadWeaponImages] Found weapon: #{weapon.granblue_id} " \
                      "(element=#{weapon.element}, series=#{weapon.weapon_series_id})"
    update_status(weapon_id, 'processing', progress: 0, images_downloaded: 0)

    service = WeaponImageDownloadService.new(
      weapon,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadWeaponImages] Completed for weapon #{weapon_id}"
      update_status(
        weapon_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadWeaponImages] Failed for weapon #{weapon_id}: #{result.error}"
      update_status(weapon_id, 'failed', error: result.error)
      raise StandardError, result.error # Trigger retry
    end
  end

  private

  def update_status(weapon_id, status, **attrs)
    self.class.update_status(weapon_id, status, **attrs)
  end
end
