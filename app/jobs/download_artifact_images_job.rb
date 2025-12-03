# frozen_string_literal: true

# Background job for downloading artifact images from Granblue servers to S3.
# Stores progress in Redis for status polling.
#
# @example Enqueue a download job
#   job = DownloadArtifactImagesJob.perform_later(artifact.id)
#   # Poll status with: DownloadArtifactImagesJob.status(artifact.id)
class DownloadArtifactImagesJob < ApplicationJob
  queue_as :downloads

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, _error|
    artifact_id = job.arguments.first
    Rails.logger.error "[DownloadArtifactImages] Artifact #{artifact_id} not found"
    update_status(artifact_id, 'failed', error: 'Artifact not found')
  end

  # Status keys for Redis storage
  REDIS_KEY_PREFIX = 'artifact_image_download'
  STATUS_TTL = 1.hour.to_i

  class << self
    # Get the current status of a download job for an artifact
    #
    # @param artifact_id [String] UUID of the artifact
    # @return [Hash] Status hash with :status, :progress, :images_downloaded, :images_total, :error
    def status(artifact_id)
      data = redis.get(redis_key(artifact_id))
      return { status: 'not_found' } unless data

      JSON.parse(data, symbolize_names: true)
    end

    def redis_key(artifact_id)
      "#{REDIS_KEY_PREFIX}:#{artifact_id}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

    def update_status(artifact_id, status, **attrs)
      data = { status: status, updated_at: Time.current.iso8601 }.merge(attrs)
      redis.setex(redis_key(artifact_id), STATUS_TTL, data.to_json)
    end
  end

  def perform(artifact_id, force: false, size: 'all')
    Rails.logger.info "[DownloadArtifactImages] Starting download for artifact #{artifact_id}"

    artifact = Artifact.find(artifact_id)
    update_status(artifact_id, 'processing', progress: 0, images_downloaded: 0)

    service = ArtifactImageDownloadService.new(
      artifact,
      force: force,
      size: size,
      storage: :s3
    )

    result = service.download

    if result.success?
      Rails.logger.info "[DownloadArtifactImages] Completed for artifact #{artifact_id}"
      update_status(
        artifact_id,
        'completed',
        progress: 100,
        images_downloaded: result.total,
        images_total: result.total,
        images: result.images
      )
    else
      Rails.logger.error "[DownloadArtifactImages] Failed for artifact #{artifact_id}: #{result.error}"
      update_status(artifact_id, 'failed', error: result.error)
      raise StandardError, result.error # Trigger retry
    end
  end

  private

  def update_status(artifact_id, status, **attrs)
    self.class.update_status(artifact_id, status, **attrs)
  end
end
