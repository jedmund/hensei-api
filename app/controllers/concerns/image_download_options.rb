# frozen_string_literal: true

# Checks the size requested from the image download endpoints. The sync
# (download_image) and async (download_images) actions share it, since the
# size ends up in storage keys and paths either way.
module ImageDownloadOptions
  extend ActiveSupport::Concern

  private

  # Returns the size, or renders a 422 and returns nil. The async actions
  # also accept 'all' (every size), which is their default.
  def validated_download_size(size, sizes, allow_all: false)
    allowed = allow_all ? ['all', *sizes] : sizes
    return size if allowed.include?(size)

    render json: { error: "Invalid size. Must be one of: #{allowed.join(', ')}" }, status: :unprocessable_entity
    nil
  end
end
