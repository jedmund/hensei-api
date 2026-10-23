# frozen_string_literal: true

# Rejects upload requests whose declared body is larger than a limit with a
# 413, before authentication or anything else reads (and parses) the body.
#
#   include UploadSizeLimit
#   limit_upload_size 512.kilobytes, only: :upload_image
#
# Pick the limit from the decoded image cap: base64 adds about a third, plus
# room for the rest of the request.
module UploadSizeLimit
  extend ActiveSupport::Concern

  class_methods do
    def limit_upload_size(max_bytes, only:)
      prepend_before_action(only: only) { reject_oversized_upload(max_bytes) }
    end
  end

  private

  def reject_oversized_upload(max_bytes)
    return if request.content_length.to_i <= max_bytes

    render json: { error: "Request body exceeds #{max_bytes / 1024}KB" }, status: :payload_too_large
  end
end
