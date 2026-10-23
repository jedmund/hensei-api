# frozen_string_literal: true

require 'net/http'
require 'open-uri'

module Granblue
  module Downloaders
    # Fetches one asset from the game CDN (or another fixed asset host) for the downloaders,
    # in place of open-uri. The hosts are constants, so this is defense in depth: it only
    # speaks https, follows a redirect only when it stays on the same host, stops reading
    # past MAX_BYTES, and times out instead of waiting on a stalled connection.
    #
    # Returns a rewindable StringIO (or yields it). A non-2xx answer raises HTTPError, an
    # OpenURI::HTTPError, so the downloaders' existing "404 returned" handling is unchanged.
    module RemoteFile
      # The largest assets we fetch are full-size art PNGs (job art from media.skycompass.io at
      # 1138x1138, character and raid backgrounds), a few MB at most. 16 MiB leaves room for
      # larger art and still bounds what one download can buffer in memory.
      MAX_BYTES = 16 * 1024 * 1024
      MAX_REDIRECTS = 3
      OPEN_TIMEOUT = 5 # seconds
      READ_TIMEOUT = 15 # seconds, per read
      TOTAL_TIMEOUT = 60 # seconds for the whole body, so a slow trickle can't run forever

      class Error < StandardError; end

      # A non-2xx answer; is_a OpenURI::HTTPError like open-uri's.
      class HTTPError < OpenURI::HTTPError; end

      class RedirectRefused < Error; end

      class TooLarge < Error; end

      class << self
        def open(url, max_bytes: MAX_BYTES)
          io = fetch(url, max_bytes: max_bytes)
          block_given? ? yield(io) : io
        end

        private

        def fetch(url, max_bytes:)
          origin = parse_https(url)
          uri = origin

          (MAX_REDIRECTS + 1).times do
            result = request(uri, max_bytes)
            return result unless result.is_a?(URI)

            uri = same_host_redirect(origin, uri, result)
          end

          raise RedirectRefused, "more than #{MAX_REDIRECTS} redirects for #{origin}"
        end

        def parse_https(url)
          uri = URI.parse(url.to_s)
          raise Error, "only https URLs can be fetched: #{url}" unless uri.is_a?(URI::HTTPS) && uri.host.present?

          uri
        end

        # Returns the body as a StringIO, or the redirect target as a URI.
        def request(uri, max_bytes)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TOTAL_TIMEOUT

          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT,
                                              read_timeout: READ_TIMEOUT, write_timeout: READ_TIMEOUT) do |http|
            http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
              case response
              when Net::HTTPSuccess then return read_body(response, uri, max_bytes, deadline)
              when Net::HTTPRedirection then return redirect_target(uri, response)
              else
                raise HTTPError.new("#{response.code} #{response.message}".strip, StringIO.new)
              end
            end
          end
        end

        def read_body(response, uri, max_bytes, deadline)
          if response.content_length && response.content_length > max_bytes
            raise TooLarge, "#{uri} is #{response.content_length} bytes (limit #{max_bytes})"
          end

          body = StringIO.new(+'', 'w+b')
          response.read_body do |chunk|
            body.write(chunk)
            raise TooLarge, "#{uri} is over #{max_bytes} bytes" if body.size > max_bytes
            raise Net::ReadTimeout, "#{uri} took over #{TOTAL_TIMEOUT}s" if past?(deadline)
          end
          body.rewind
          body
        end

        def redirect_target(uri, response)
          location = response['location']
          raise RedirectRefused, "redirect without a location from #{uri}" if location.blank?

          uri + location
        rescue URI::Error
          raise RedirectRefused, "invalid redirect location from #{uri}"
        end

        def same_host_redirect(origin, from, target)
          unless target.is_a?(URI::HTTPS) && target.host&.casecmp?(origin.host) && target.port == origin.port
            raise RedirectRefused, "refused redirect from #{from} to another host (#{target.host})"
          end

          target
        end

        def past?(deadline)
          Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        end
      end
    end
  end
end
