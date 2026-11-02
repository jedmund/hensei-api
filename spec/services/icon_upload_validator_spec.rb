# frozen_string_literal: true

require 'rails_helper'

# The checks read the file's header only (it isn't decoded), so these
# fixtures are tiny real images, embedded so the spec needs no image library.
RSpec.describe IconUploadValidator do
  png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAIAAAADAQMAAACDJEzCAAAAA1BMVEX/AAAZ4gk3AAAAC0lEQVQI12NgAAEAAAYAAWb0yWwAAAAASUVORK5CYII=') # 2x3
  jpeg = Base64.decode64(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQ' \
    'CgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ' \
    'EBD/wAARCAACAAMDAREAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAVAQEBAAAAAAAA' \
    'AAAAAAAAAAAGCf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AD3VTB3/2Q=='
  ) # 3x2
  webp = Base64.decode64('UklGRjgAAABXRUJQVlA4ICwAAADQAQCdASoEAAUAAgA0JaACdLoB+AADsAD+8Oj3/yC5YXXI1/5sCua5+agAAA==') # 4x5
  # 300x10
  wide_png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAASwAAAAKAQMAAAA0MfGpAAAAA1BMVEX/AAAZ4gk3AAAADUlEQVQY02NgGAUDDwABhgABKkVenAAAAABJRU5ErkJggg==')
  gif = Base64.decode64('R0lGODlhAgACAPAAAP8AAAAAACH5BAAAAAAALAAAAAACAAIAAAIChFEAOw==')

  all_formats = { formats: %w[PNG WEBP JPEG] }

  it 'accepts a PNG by default and reports its extension and content type' do
    result = described_class.call(png)
    expect(result).to be_valid
    expect([result.format, result.extension, result.content_type]).to eq(['PNG', 'png', 'image/png'])
  end

  it 'accepts JPEG and WebP where the caller allows them' do
    expect(described_class.call(jpeg, **all_formats)).to have_attributes(valid?: true, format: 'JPEG',
                                                                         extension: 'jpg')
    expect(described_class.call(webp, **all_formats)).to have_attributes(valid?: true, format: 'WEBP',
                                                                         content_type: 'image/webp')
  end

  it 'rejects formats the caller does not allow, naming the ones it does' do
    expect(described_class.call(jpeg).error).to eq('Image must be a PNG')
    expect(described_class.call(gif, **all_formats).error).to eq('Image must be a PNG, WebP or JPEG')
  end

  it 'rejects images larger than the maximum dimension, either way' do
    result = described_class.call(wide_png, max_dimension: 128)
    expect(result).not_to be_valid
    expect(result.error).to eq('Image must be 128x128 or smaller')
    expect(described_class.call(wide_png, max_dimension: 300)).to be_valid
  end

  it 'rejects files over the byte limit before reading them' do
    expect(described_class.call(png, max_bytes: 10).error).to eq('Image must be 0KB or smaller')
  end

  it 'rejects missing data' do
    expect(described_class.call(nil).error).to eq('No image data provided')
    expect(described_class.call('').error).to eq('No image data provided')
  end

  it 'rejects a file whose signature is right but whose header is not readable' do
    truncated = png.byteslice(0, 12)
    expect(described_class.call(truncated).error).to eq('Image could not be read')
  end
end
