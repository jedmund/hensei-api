# frozen_string_literal: true

require 'httparty'
require 'uri'

module Granblue
  module Parsers
    # Fetches raw HTML pages from the Japanese wiki (gbf-wiki.com). Unlike gbf.wiki
    # (English) this is a PukiWiki site with no structured API, so we fetch the
    # rendered HTML page and parse it elsewhere. Pages are served UTF-8; titles are
    # stored decoded in wiki_ja (a few legacy rows are EUC-JP percent-encoded).
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

      # Current wiki_ja rows are plain Japanese; legacy rows may be EUC-JP
      # percent-encoded. Decode the latter, pass the former through untouched.
      def resolve_title(title)
        text = title.to_s
        return text unless text.match?(/%[0-9A-Fa-f]{2}/)

        bytes = text.gsub(/%([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr }.b
        bytes.force_encoding('EUC-JP').encode('UTF-8')
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        text
      end

      # PukiWiki query string: UTF-8 percent-encoded title.
      def encode_title(title)
        URI.encode_www_form_component(title)
      end

      def handle_response(response, title)
        case response.code
        when 200 then response.body
        when 404 then raise WikiError.new(code: 404, message: 'Page not found', page: title)
        when 500...600 then raise WikiError.new(code: response.code, message: 'Server error', page: title)
        else raise WikiError.new(code: response.code, message: 'Unexpected response', page: title)
        end
      end
    end
  end
end
