# frozen_string_literal: true

class BulletImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(bullet, options = {})
    @bullet = bullet
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  def download
    downloader = Granblue::Downloaders::BulletDownloader.new(
      @bullet.granblue_id,
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
    Rails.logger.error "[BulletImageDownload] Failed for #{@bullet.granblue_id}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    sizes = Granblue::Downloaders::BulletDownloader::SIZES

    sizes.each_with_object({}) do |size, manifest|
      manifest[size] = ["#{@bullet.granblue_id}.jpg"]
    end
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
