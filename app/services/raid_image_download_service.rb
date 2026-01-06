# frozen_string_literal: true

# Service wrapper for downloading raid images from Granblue servers to S3.
# Uses the RaidDownloader but provides a cleaner interface for controllers.
#
# @example Download images for a raid
#   service = RaidImageDownloadService.new(raid)
#   result = service.download
#   if result.success?
#     puts result.images
#   else
#     puts result.error
#   end
class RaidImageDownloadService
  Result = Struct.new(:success?, :images, :error, :total, keyword_init: true)

  def initialize(raid, options = {})
    @raid = raid
    @force = options[:force] || false
    @size = options[:size] || 'all'
    @storage = options[:storage] || :s3
  end

  # Downloads images for the raid
  #
  # @return [Result] Struct with success status, images manifest, and any errors
  def download
    downloader = Granblue::Downloaders::RaidDownloader.new(
      @raid,
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
    Rails.logger.error "[RaidImageDownload] Failed for #{@raid.slug}: #{e.message}"
    Result.new(
      success?: false,
      error: e.message
    )
  end

  private

  def build_image_manifest
    manifest = {}

    if @raid.enemy_id
      manifest['icon'] = ["#{@raid.enemy_id}.png"]
    end

    if @raid.summon_id
      manifest['thumbnail'] = ["#{@raid.summon_id}_high.png"]
    end

    if @raid.quest_id
      manifest['lobby'] = ["#{@raid.quest_id}1.png"]
      manifest['background'] = ["#{@raid.quest_id}_raid_image_new.png"]
    end

    manifest
  end

  def count_total_images(manifest)
    manifest.values.sum(&:size)
  end
end
