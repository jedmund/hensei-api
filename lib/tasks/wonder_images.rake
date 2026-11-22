# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download Wonder art from the game CDN to wonders/square/<image>.jpg (S3 and/or local),
    including every level's art for Crucible Seals and Yupei and Symbolum's variants.
    Usage:
      rake granblue:download_wonder_images                       # storage=both
      rake granblue:download_wonder_images storage=s3 force=true
      rake granblue:download_wonder_images only=9008,9015
  DESC
  task download_wonder_images: :environment do
    storage = (ENV['storage'] || 'both').to_sym
    force = ENV['force'] == 'true'
    only = ENV['only']&.split(',')&.map(&:strip)

    scope = Wonder.order(:granblue_id)
    scope = scope.where(granblue_id: only) if only.present?

    scope.find_each do |wonder|
      Granblue::Downloaders::WonderDownloader.new(
        wonder.granblue_id, storage: storage, force: force, verbose: true, logger: Logger.new($stdout)
      ).download
    end
  end
end
