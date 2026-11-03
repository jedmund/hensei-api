# frozen_string_literal: true

# Validates a raw (binary-decoded) image for editor-uploaded assets.
#
# Used by Difficulty tier icon uploads (PNG only, the defaults), sticker images
# (PNG or WebP) and event banners (PNG, WebP or JPEG). The result carries the
# detected format so callers can pick a file extension and content type.
#
# Format and dimensions come from the file's header (FastImage), so no image
# library has to be installed on the server. Uploads are stored as sent.
class IconUploadValidator
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
  JPEG_SIGNATURE = "\xFF\xD8\xFF".b
  DEFAULT_MAX_DIMENSION = 128
  DEFAULT_MAX_BYTES = 256 * 1024
  DEFAULT_FORMATS = %w[PNG].freeze

  # Format name => [file extension, content type]
  FORMATS = {
    'PNG' => ['png', 'image/png'],
    'WEBP' => ['webp', 'image/webp'],
    'JPEG' => ['jpg', 'image/jpeg']
  }.freeze

  Result = Struct.new(:valid?, :error, :format, keyword_init: true) do
    def extension
      FORMATS.dig(format, 0)
    end

    def content_type
      FORMATS.dig(format, 1)
    end
  end

  def self.call(decoded_bytes, max_dimension: DEFAULT_MAX_DIMENSION, max_bytes: DEFAULT_MAX_BYTES,
                formats: DEFAULT_FORMATS)
    new(decoded_bytes, max_dimension: max_dimension, max_bytes: max_bytes, formats: formats).call
  end

  def initialize(decoded_bytes, max_dimension:, max_bytes:, formats: DEFAULT_FORMATS)
    @bytes = decoded_bytes
    @max_dimension = max_dimension
    @max_bytes = max_bytes
    @formats = formats
  end

  # FastImage's type for each format
  HEADER_TYPES = { 'PNG' => :png, 'JPEG' => :jpeg, 'WEBP' => :webp }.freeze

  def call
    return invalid('No image data provided') if @bytes.blank?
    return invalid("Image must be #{@max_bytes / 1024}KB or smaller") if @bytes.bytesize > @max_bytes

    format = signature_format
    return invalid(format_error) unless format && @formats.include?(format)

    header = FastImage.new(StringIO.new(@bytes.b))
    width, height = header.size
    # The header has to agree with the signature, and give dimensions
    return invalid('Image could not be read') unless header.type == HEADER_TYPES[format] && width && height

    return invalid("Image must be #{@max_dimension}x#{@max_dimension} or smaller") if width > @max_dimension || height > @max_dimension

    Result.new(valid?: true, error: nil, format: format)
  end

  private

  def signature_format
    bytes = @bytes.b
    return 'PNG' if bytes.start_with?(PNG_SIGNATURE)
    return 'JPEG' if bytes.start_with?(JPEG_SIGNATURE)
    return 'WEBP' if bytes.byteslice(0, 4) == 'RIFF' && bytes.byteslice(8, 4) == 'WEBP'

    nil
  end

  def format_error
    names = @formats.map { |f| f == 'WEBP' ? 'WebP' : f }
    "Image must be a #{names.to_sentence(two_words_connector: ' or ', last_word_connector: ' or ')}"
  end

  def invalid(message)
    Result.new(valid?: false, error: message, format: nil)
  end
end
