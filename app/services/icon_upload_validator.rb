# frozen_string_literal: true

# Validates a raw (binary-decoded) PNG icon for editor-uploaded assets.
#
# Used by Difficulty tier icon uploads; intended to be the shared validator
# for any other editor-uploadable icon (e.g. Roles when they grow drafts).
class IconUploadValidator
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
  DEFAULT_MAX_DIMENSION = 128
  DEFAULT_MAX_BYTES = 256 * 1024

  Result = Struct.new(:valid?, :error, keyword_init: true)

  def self.call(decoded_bytes, max_dimension: DEFAULT_MAX_DIMENSION, max_bytes: DEFAULT_MAX_BYTES)
    new(decoded_bytes, max_dimension: max_dimension, max_bytes: max_bytes).call
  end

  def initialize(decoded_bytes, max_dimension:, max_bytes:)
    @bytes = decoded_bytes
    @max_dimension = max_dimension
    @max_bytes = max_bytes
  end

  def call
    return invalid('No image data provided') if @bytes.blank?
    return invalid("Icon must be #{@max_bytes / 1024}KB or smaller") if @bytes.bytesize > @max_bytes
    return invalid('Icon must be a PNG') unless @bytes.start_with?(PNG_SIGNATURE)

    Tempfile.create(['icon', '.png']) do |tmp|
      tmp.binmode
      tmp.write(@bytes)
      tmp.flush

      image = MiniMagick::Image.open(tmp.path)
      return invalid('Icon must be a PNG') unless image.type == 'PNG'

      if image.width > @max_dimension || image.height > @max_dimension
        return invalid("Icon must be #{@max_dimension}x#{@max_dimension} or smaller")
      end
    end

    Result.new(valid?: true, error: nil)
  rescue MiniMagick::Invalid
    invalid('Icon could not be read as an image')
  end

  private

  def invalid(message)
    Result.new(valid?: false, error: message)
  end
end
