# frozen_string_literal: true

module Granblue
  # The minimum wait between requests to gbf.wiki or gbf-wiki.com. Every fetch
  # loop waits at least this long; a shorter requested delay is raised to it.
  module WikiThrottle
    MIN_DELAY = 2.0

    # The delay to use for a requested value (nil → MIN_DELAY). Calls warn with
    # a note when the request was below the minimum.
    def self.clamp(requested, warn: nil)
      return MIN_DELAY if requested.nil?

      delay = requested.to_f
      return delay if delay >= MIN_DELAY

      warn&.call("Wiki delay #{delay}s is below the #{MIN_DELAY}s minimum; using #{MIN_DELAY}s.")
      MIN_DELAY
    end

    # Waits between two wiki requests. Every fetch loop sleeps through here, so a
    # spec can stub this one method instead of Kernel#sleep.
    def self.wait(seconds)
      sleep(seconds) if seconds.to_f.positive?
    end
  end
end
