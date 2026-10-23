# frozen_string_literal: true

require 'httparty'
require 'uri'

module Granblue
  module Parsers
    # Fetches raw HTML pages from the Japanese wiki (gbf-wiki.com). Unlike gbf.wiki
    # (English) this is a PukiWiki site with no structured API, so we fetch the
    # rendered HTML page and parse it elsewhere. Pages are served UTF-8; titles are
    # stored plain in wiki_ja (Granblue::JpWikiTitle decodes any left percent-encoded).
    class JpWiki
      class_attribute :base_uri
      self.base_uri = 'https://gbf-wiki.com/'

      def initialize(debug: false)
        @debug = debug
      end

      def fetch(title)
        url = url_for(title)
        Rails.logger.info "[JP_WIKI] fetching #{url}" if @debug

        response = HTTParty.get(url, headers: headers, follow_redirects: true)
        handle_response(response, title)
      end

      def url_for(title)
        "#{base_uri}?#{encode_title(resolve_title(title))}"
      end

      private

      def headers
        { 'User-Agent' => Rails.application.credentials.wiki_user_agent.presence || 'hensei-api' }
      end

      # Stored titles may still be percent-encoded (UTF-8 or legacy EUC-JP); raises
      # Granblue::JpWikiTitle::InvalidTitle rather than fetching a garbled title.
      def resolve_title(title)
        Granblue::JpWikiTitle.decode!(title.to_s)
      end

      # PukiWiki query string: UTF-8 percent-encoded title.
      def encode_title(title)
        URI.encode_www_form_component(title)
      end

      # gbf-wiki.com sometimes returns a 200 with a "Runtime error" HTML page
      # (NG word filter, IP restriction, etc.). Detect and reject it so the
      # caller treats it as an error rather than caching garbage HTML.
      RUNTIME_ERROR_MARKERS = [
        '<h1 class="title">Runtime error</h1>',
        '<title>Runtime error'
      ].freeze
      private_constant :RUNTIME_ERROR_MARKERS

      def handle_response(response, title)
        case response.code
        when 200
          body = response.body
          if runtime_error?(body)
            raise WikiError.new(code: 200, message: 'Runtime error page returned', page: title)
          end

          body
        when 404 then raise WikiError.new(code: 404, message: 'Page not found', page: title)
        when 500...600 then raise WikiError.new(code: response.code, message: 'Server error', page: title)
        else raise WikiError.new(code: response.code, message: 'Unexpected response', page: title)
        end
      end

      def runtime_error?(body)
        text = body.to_s
        RUNTIME_ERROR_MARKERS.any? { |marker| text.include?(marker) }
      end
    end
  end
end
