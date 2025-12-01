# frozen_string_literal: true

# Service wrapper for downloading summon images from Granblue servers to S3.
# Uses the existing SummonDownloader but provides a cleaner interface for controllers.
#
# @example Download images for a summon
#   service = SummonImageDownloadService.new(summon)
#   result = service.download
#   if result.success?
#     puts result.images
#   else
#     puts result.error
#   end
class SummonImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(summon, options = {})
    @summon = summon
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  # Downloads images for the summon
  #
  # @return [Result] Struct with success status, images manifest, and any errors
  def download
    downloader = Granblue::Downloaders::SummonDownloader.new(
      @summon.granblue_id,
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
    Rails.logger.error "[SummonImageDownload] Failed for #{@summon.granblue_id}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    sizes = Granblue::Downloaders::SummonDownloader::SIZES
    variants = build_variants

    sizes.each_with_object({}) do |size, manifest|
      manifest[size] = variants.map do |variant|
        extension = size == 'detail' ? 'png' : 'jpg'
        "#{variant}.#{extension}"
      end
    end
  end

  def build_variants
    # Summons use the raw granblue_id for base variant (no _01 suffix)
    variants = [@summon.granblue_id]
    variants << "#{@summon.granblue_id}_02" if @summon.ulb
    if @summon.transcendence
      variants << "#{@summon.granblue_id}_03"
      variants << "#{@summon.granblue_id}_04"
    end
    variants
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
