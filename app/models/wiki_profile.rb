# frozen_string_literal: true

require 'cgi'

##
# A user's gbf.wiki username, as stored on User#wiki_profile: the name only.
# People type the name, "User:Name", or paste their user page's URL
# (gbf.wiki/User:Name, or index.php?title=User:Name); `normalize` keeps just
# the name. Anything that isn't a name (another page's URL, characters
# MediaWiki forbids in usernames) is returned as typed, so the format
# validation can reject it.
module WikiProfile
  # MediaWiki usernames can't contain these, and are at most 85 bytes
  FORMAT = %r{\A[^\#<>\[\]|{}/:@\n]{1,85}\z}
  URL_PREFIX = %r{\A(?:https?://)?(?:www\.)?gbf\.wiki/}i

  def self.normalize(value)
    typed = value.to_s.strip
    return nil if typed.empty?

    name = typed.match?(URL_PREFIX) ? from_url(typed) : typed
    return typed if name.nil?

    name.sub(/\AUser:/i, '').strip.presence || typed
  end

  # The name from a user page URL, or nil for any other page
  def self.from_url(url)
    rest = url.sub(URL_PREFIX, '')
    title = if rest.start_with?('index.php')
              CGI.parse(rest.split('?', 2)[1].to_s)['title']&.first
            else
              rest.split(/[?#]/).first
            end
    title = CGI.unescape(title.to_s)
    return nil unless title.match?(/\AUser:/i)

    title.chomp('/')
  end
end
