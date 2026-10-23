# frozen_string_literal: true

module Granblue
  # Timeouts for requests to gbf.wiki and gbf-wiki.com. Editor requests fetch the wiki
  # synchronously, so a wiki that stops answering must not hold a web worker. A timeout
  # becomes a WikiError (code 504), which every caller already turns into a clean error,
  # and which the source fetcher still retries (it retries 5xx codes).
  module WikiHttp
    OPEN_TIMEOUT = 5 # seconds, as SocialAuth::Http
    # Longer than the open timeout: action=parse and action=expandtemplates render the page
    # server-side, and the large series pages are slow even when the wiki is healthy.
    READ_TIMEOUT = 15 # seconds

    OPTIONS = { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, write_timeout: READ_TIMEOUT }.freeze

    TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout].freeze

    def self.with_timeouts(page)
      yield
    rescue *TIMEOUT_ERRORS => e
      raise WikiError.new(code: 504, message: "Timed out (#{e.class.name.demodulize})", page: page)
    end
  end
end
