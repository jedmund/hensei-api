# frozen_string_literal: true

##
# A user's YouTube channel, as stored on User#youtube: "@handle", or
# "channel/UC…" for a channel linked by its ID (those have no handle).
# People type a handle with or without the @, or paste their channel's URL;
# `normalize` turns all of those into the stored form. Anything else is
# returned as typed, so the format validation can reject it.
module YoutubeChannel
  HANDLE = '[A-Za-z0-9._-]{1,100}'
  CHANNEL_ID = 'UC[A-Za-z0-9_-]{22}'
  FORMAT = %r{\A(?:@#{HANDLE}|channel/#{CHANNEL_ID})\z}
  URL_PREFIX = %r{\A(?:https?://)?(?:(?:www|m)\.)?youtube\.com/}i

  def self.normalize(value)
    typed = value.to_s.strip
    return nil if typed.empty?
    return from_url(typed) if typed.match?(URL_PREFIX)

    handle = typed.delete_prefix('@')
    handle.match?(/\A#{HANDLE}\z/o) ? "@#{handle}" : typed
  end

  def self.from_url(url)
    path = url.sub(URL_PREFIX, '').split(/[?#]/).first.to_s
    if (match = path.match(%r{\A@(#{HANDLE})(?:/|\z)}o))
      "@#{match[1]}"
    elsif (match = path.match(%r{\Achannel/(#{CHANNEL_ID})(?:/|\z)}o))
      "channel/#{match[1]}"
    else
      url
    end
  end
end
