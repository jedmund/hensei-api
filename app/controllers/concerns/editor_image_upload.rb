# frozen_string_literal: true

# Reads and stores an editor-uploaded image for a record with an `image_key`
# column. Accepts the `image` param as a multipart file or, like the
# awakenings upload, as a base64 string.
module EditorImageUpload
  extend ActiveSupport::Concern

  private

  # Validates the upload and stores it at "<prefix>/<name>.<ext>", replacing
  # the record's previous image. Returns the record, or renders a 422 and
  # returns nil on failure.
  def store_editor_image(record, prefix:, name:, **validator_options)
    bytes = uploaded_image_bytes(params[:image])
    result = IconUploadValidator.call(bytes, **validator_options)
    unless result.valid?
      render json: { error: result.error }, status: :unprocessable_entity
      return nil
    end

    key = "#{prefix}/#{name}.#{result.extension}"
    previous_key = record.image_key
    IconStorage.put(key, bytes, content_type: result.content_type)
    record.update!(image_key: key)
    remove_replaced_image(previous_key) if previous_key.present? && previous_key != key
    record
  end

  def uploaded_image_bytes(value)
    if value.respond_to?(:read)
      value.rewind if value.respond_to?(:rewind)
      value.read.to_s.b
    elsif value.is_a?(String)
      bytes = value.b
      return bytes if bytes.start_with?(IconUploadValidator::PNG_SIGNATURE)

      Base64.decode64(value.sub(/\Adata:[^,]*,/, ''))
    else
      ''
    end
  end

  def remove_replaced_image(key)
    IconStorage.delete(key)
  rescue StandardError => e
    Rails.logger.warn("[editor_image_upload] failed to delete #{key}: #{e.class}")
  end
end
