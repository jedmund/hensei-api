# frozen_string_literal: true

class Dataminer
  ##
  # One logged-in game session: its cookies and the requests sent with them.
  #
  # The server rotates the `midship` cookie on every response; the session
  # follows it so a batch keeps a live session. The debug trail shows each
  # request and response with cookie values filtered out.
  class Session
    include HTTParty

    base_uri 'https://game.granbluefantasy.jp'
    format :json

    HEADERS = {
      'Accept' => 'application/json, text/javascript, */*; q=0.01',
      'Accept-Language' => 'en-US,en;q=0.9',
      'Accept-Encoding' => 'gzip, deflate, br, zstd',
      'Content-Type' => 'application/json',
      'DNT' => '1',
      'Origin' => 'https://game.granbluefantasy.jp',
      'Referer' => 'https://game.granbluefantasy.jp/',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
      'X-Requested-With' => 'XMLHttpRequest'
    }.freeze

    FILTERED = '[FILTERED]'

    # @param cookies [Hash{Symbol => String}] access_gbtk, wing, t and midship
    # @param user_id [String] the logged-in account's player id
    # @param game_version [String] the current game build
    # @param logger [Logger]
    def initialize(cookies:, user_id:, game_version:, logger:)
      @cookies = cookies.dup
      @user_id = user_id
      @game_version = game_version
      @logger = logger
    end

    attr_reader :user_id

    ##
    # Posts to a game page.
    #
    # @param page [String]
    # @return [HTTParty::Response]
    # @raise [AuthenticationError] when the game rejects the session
    def post_page(page)
      response = self.class.post(timestamped("/#{page}"), headers: headers)
      raise AuthenticationError if auth_failed?(response)

      response
    end

    ##
    # Posts an archive detail request.
    #
    # @param kind [String] 'npc', 'weapon' or 'summon'
    # @param ids [Hash] the item's id (and a character's style)
    # @return [Object] the parsed response
    # @raise [AuthenticationError] when the game rejects the session
    def detail(kind, **ids)
      url = timestamped("/archive/#{kind}_detail")
      body = { special_token: nil, user_id: user_id, kind_name: '0', attribute: '0', event_id: nil,
               story_id: nil, **ids }
      log_request(url, body)

      response = self.class.post(url, headers: headers, body: body.to_json)
      rotate_midship!(response)
      log_response(response)
      raise AuthenticationError if auth_failed?(response)

      JSON.parse(response.body)
    end

    private

    def timestamped(path)
      timestamp = Time.now.to_i * 1000
      "#{path}?_=#{timestamp}&t=#{timestamp}&uid=#{user_id}"
    end

    def headers(cookie = format_cookies)
      HEADERS.merge('Cookie' => cookie, 'X-VERSION' => @game_version)
    end

    def format_cookies
      @cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
    end

    # Follow the server's rotating `midship` token by reading it back out of the
    # response Set-Cookie header and storing it for the next request.
    def rotate_midship!(response)
      set_cookie = response.headers['set-cookie']
      return if set_cookie.blank?

      midship = Array(set_cookie).join('; ')[/midship=([^;,\s]+)/, 1]
      @cookies[:midship] = midship if midship.present?
    end

    def auth_failed?(response)
      return true if response.code != 200

      begin
        parsed = JSON.parse(response.body)
        parsed.is_a?(Hash) && parsed['auth_status'] == 'require_auth'
      rescue JSON::ParserError
        true
      end
    end

    def log_request(url, body)
      @logger.debug "\n=== Request Details ==="
      @logger.debug "URL: #{url}"
      @logger.debug 'Headers:'
      @logger.debug headers(@cookies.keys.map { |k| "#{k}=#{FILTERED}" }.join('; ')).inspect
      @logger.debug 'Body:'
      @logger.debug body.to_json
      @logger.debug '===================='
    end

    def log_response(response)
      @logger.debug "\n=== Response Details ==="
      @logger.debug "Response code: #{response.code}"
      @logger.debug 'Response headers:'
      @logger.debug response.headers.to_h.except('set-cookie').inspect
      @logger.debug 'Raw response body:'
      @logger.debug response.body.inspect
      log_parsed_body(response.body)
      @logger.debug '======================'
    end

    def log_parsed_body(body)
      @logger.debug 'Parsed response body (if JSON):'
      @logger.debug JSON.parse(body).inspect
    rescue JSON::ParserError => e
      @logger.debug "Could not parse as JSON: #{e.message}"
    end
  end
end
