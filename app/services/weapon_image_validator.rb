# frozen_string_literal: true

# Validates that a granblue_id has accessible images on the Granblue Fantasy game server.
# Used to verify that a weapon ID is valid before creating a database record.
#
# @example Validate a weapon ID
#   validator = WeaponImageValidator.new("1040001000")
#   if validator.valid?
#     puts validator.image_urls
#   else
#     puts validator.error_message
#   end
class WeaponImageValidator
  BASE_URL = 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/weapon'

  SIZES = {
    main: 'ls',
    grid: 'm',
    square: 's'
  }.freeze

  attr_reader :granblue_id, :error_message, :image_urls

  def initialize(granblue_id)
    @granblue_id = granblue_id.to_s
    @error_message = nil
    @image_urls = {}
  end

  # Validates the granblue_id by checking if the main image is accessible.
  #
  # @return [Boolean] true if valid, false otherwise
  def valid?
    return invalid_format unless valid_format?

    check_image_accessibility
  end

  # Checks if a weapon with this granblue_id already exists in the database.
  #
  # @return [Boolean] true if exists, false otherwise
  def exists_in_db?
    Weapon.exists?(granblue_id: @granblue_id)
  end

  private

  def valid_format?
    @granblue_id.present? && @granblue_id.match?(/^\d{10}$/)
  end

  def invalid_format
    @error_message = 'Invalid granblue_id format. Must be a 10-digit number.'
    false
  end

  def check_image_accessibility
    # Weapons use the raw granblue_id without variant suffix for base image
    variant_id = @granblue_id

    # Build image URLs for all sizes
    SIZES.each do |size_name, directory|
      url = "#{BASE_URL}/#{directory}/#{variant_id}.jpg"
      @image_urls[size_name] = url
    end

    # Check if the main image is accessible via HEAD request
    main_url = @image_urls[:main]

    begin
      uri = URI.parse(main_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5
      # Skip CRL verification in development (Akamai CDN can have CRL issues locally)
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

      request = Net::HTTP::Head.new(uri.request_uri)
      response = http.request(request)

      if response.code == '200'
        true
      else
        @error_message = "No images found for this granblue_id (HTTP #{response.code})"
        false
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      @error_message = "Request timed out while validating image URL: #{e.message}"
      false
    rescue StandardError => e
      @error_message = "Failed to validate image URL: #{e.message}"
      false
    end
  end
end
