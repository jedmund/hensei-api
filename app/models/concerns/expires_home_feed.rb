# frozen_string_literal: true

# Clears the cached Home feed after any change, so editors see their edits to
# events and staff picks on Home right away instead of after the cache expires.
module ExpiresHomeFeed
  extend ActiveSupport::Concern

  included do
    after_commit { HomeFeed.expire }
  end
end
