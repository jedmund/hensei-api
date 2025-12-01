# frozen_string_literal: true

# Service wrapper for downloading weapon images from Granblue servers to S3.
# Uses the existing WeaponDownloader but provides a cleaner interface for controllers.
#
# @example Download images for a weapon
#   service = WeaponImageDownloadService.new(weapon)
#   result = service.download
#   if result.success?
#     puts result.images
#   else
#     puts result.error
#   end
class WeaponImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(weapon, options = {})
    @weapon = weapon
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  # Downloads images for the weapon
  #
  # @return [Result] Struct with success status, images manifest, and any errors
  def download
    downloader = Granblue::Downloaders::WeaponDownloader.new(
      @weapon.granblue_id,
      storage: @storage,
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
    Rails.logger.error "[WeaponImageDownload] Failed for #{@weapon.granblue_id}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    sizes = Granblue::Downloaders::WeaponDownloader::SIZES
    variants = build_variants

    sizes.each_with_object({}) do |size, manifest|
      manifest[size] = variants.map do |variant|
        extension = size == 'base' ? 'png' : 'jpg'
        "#{variant}.#{extension}"
      end
    end
  end

  def build_variants
    # Weapons use the raw granblue_id for base variant
    variants = [@weapon.granblue_id]
    if @weapon.transcendence
      variants << "#{@weapon.granblue_id}_02"
      variants << "#{@weapon.granblue_id}_03"
    end
    variants
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
