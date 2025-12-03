# frozen_string_literal: true

# Service wrapper for downloading artifact images from Granblue servers to S3.
# Uses the existing ArtifactDownloader but provides a cleaner interface for controllers.
#
# @example Download images for an artifact
#   service = ArtifactImageDownloadService.new(artifact)
#   result = service.download
#   if result.success?
#     puts result.images
#   else
#     puts result.error
#   end
class ArtifactImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(artifact, options = {})
    @artifact = artifact
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  # Downloads images for the artifact
  #
  # @return [Result] Struct with success status, images manifest, and any errors
  def download
    downloader = Granblue::Downloaders::ArtifactDownloader.new(
      @artifact.granblue_id,
      storage: @storage,
      force: @force,
      verbose: Rails.env.development?
    )

    selected_size = @size == 'all' ? nil : @size
    downloader.download(selected_size)

    manifest = build_image_manifest

    Result.new(
      success?: true,
      images: manifest,
      total: count_total_images(manifest)
    )
  rescue StandardError => e
    Rails.logger.error "[ArtifactImageDownload] Failed for #{@artifact.granblue_id}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    sizes = Granblue::Downloaders::ArtifactDownloader::SIZES

    sizes.each_with_object({}) do |size, manifest|
      manifest[size] = ["#{@artifact.granblue_id}.jpg"]
    end
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
