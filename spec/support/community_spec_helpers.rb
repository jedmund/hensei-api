# frozen_string_literal: true

# Shared helpers for the sticker specs (and, later, other community
# features).
module CommunitySpecHelpers
  # 1x1 transparent PNG.
  PNG_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='

  def bearer_headers(user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def png_bytes
    Base64.decode64(PNG_BASE64)
  end

  def png_upload
    Rack::Test::UploadedFile.new(StringIO.new(png_bytes), 'image/png', original_filename: 'sticker.png')
  end

  def jpeg_bytes
    Tempfile.create(['src', '.png']) do |tmp|
      tmp.binmode
      tmp.write(png_bytes)
      tmp.flush
      image = MiniMagick::Image.open(tmp.path)
      image.format('jpeg')
      File.binread(image.path)
    end
  end
end

RSpec.configure { |config| config.include CommunitySpecHelpers }
