# frozen_string_literal: true

# Service wrapper for downloading character images from Granblue servers to S3.
# Uses the existing CharacterDownloader but provides a cleaner interface for controllers.
#
# @example Download images for a character
#   service = CharacterImageDownloadService.new(character)
#   result = service.download
#   if result.success?
#     puts result.images
#   else
#     puts result.error
#   end
class CharacterImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(character, options = {})
    @character = character
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  # Downloads images for the character
  #
  # @return [Result] Struct with success status, images manifest, and any errors
  def download
    downloader = Granblue::Downloaders::CharacterDownloader.new(
      @character.granblue_id,
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
    Rails.logger.error "[CharacterImageDownload] Failed for #{@character.granblue_id}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    sizes = Granblue::Downloaders::CharacterDownloader::SIZES
    variants = build_variants

    sizes.each_with_object({}) do |size, manifest|
      manifest[size] = variants.map do |variant|
        extension = size == 'detail' ? 'png' : 'jpg'
        "#{variant}.#{extension}"
      end
    end
  end

  def build_variants
    poses = %w[01 02]
    poses << '03' if @character.flb
    poses << '04' if @character.transcendence

    variants = poses.map { |pose| "#{@character.granblue_id}_#{pose}" }

    # Null-element characters have element-suffixed variants
    if @character.element&.zero?
      (1..6).each do |element|
        poses.each do |pose|
          variants << "#{@character.granblue_id}_#{pose}_0#{element}"
        end
      end
    end

    variants
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
