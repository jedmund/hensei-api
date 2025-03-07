# frozen_string_literal: true

class Dataminer
  include HTTParty

  BOT_UID = '39094985'
  GAME_VERSION = '1741068713'

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

  attr_reader :page, :cookies, :logger, :debug

  def initialize(page:, access_token:, wing:, midship:, t: 'dummy', debug: false)
    @page = page
    @cookies = {
      access_gbtk: access_token,
      wing: wing,
      t: t,
      midship: midship
    }
    @debug = debug
    setup_logger
  end

  def fetch
    timestamp = Time.now.to_i * 1000
    response = self.class.post(
      "/#{page}?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}",
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => GAME_VERSION
      )
    )

    raise AuthenticationError if auth_failed?(response)

    response
  end

  def fetch_character(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/npc_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      style: 1,
      character_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Character', granblue_id, response) if response
    response
  end

  def fetch_weapon(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/weapon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      weapon_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Weapon', granblue_id, response) if response
    response
  end

  def fetch_summon(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/summon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      summon_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Summon', granblue_id, response) if response
    response
  end

  # Public batch processing methods
  def fetch_all_characters(only_missing: false)
    process_all_records('Character', only_missing: only_missing)
  end

  def fetch_all_weapons(only_missing: false)
    process_all_records('Weapon', only_missing: only_missing)
  end

  def fetch_all_summons(only_missing: false)
    process_all_records('Summon', only_missing: only_missing)
  end

  private

  def format_cookies
    cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
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

  def setup_logger
    @logger = ::Logger.new($stdout)
    @logger.level = debug ? ::Logger::DEBUG : ::Logger::INFO
    @logger.formatter = proc do |severity, _datetime, _progname, msg|
      case severity
      when 'DEBUG'
        debug ? "#{msg}\n" : ''
      else
        "#{msg}\n"
      end
    end

    # Suppress SQL logs in non-debug mode
    return if debug

    ActiveRecord::Base.logger.level = ::Logger::INFO if defined?(ActiveRecord::Base)
  end

  def fetch_detail(url, body)
    logger.debug "\n=== Request Details ==="
    logger.debug "URL: #{url}"
    logger.debug 'Headers:'
    logger.debug HEADERS.merge(
      'Cookie' => format_cookies,
      'X-VERSION' => GAME_VERSION
    ).inspect
    logger.debug 'Body:'
    logger.debug body.to_json
    logger.debug '===================='

    response = self.class.post(
      url,
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => GAME_VERSION
      ),
      body: body.to_json
    )

    logger.debug "\n=== Response Details ==="
    logger.debug "Response code: #{response.code}"
    logger.debug 'Response headers:'
    logger.debug response.headers.inspect
    logger.debug 'Raw response body:'
    logger.debug response.body.inspect
    begin
      logger.debug 'Parsed response body (if JSON):'
      logger.debug JSON.parse(response.body).inspect
    rescue JSON::ParserError => e
      logger.debug "Could not parse as JSON: #{e.message}"
    end
    logger.debug '======================'

    raise AuthenticationError if auth_failed?(response)

    JSON.parse(response.body)
  end

  def update_game_data(model_name, granblue_id, response_data)
    return unless response_data.is_a?(Hash)

    model = Object.const_get(model_name)
    record = model.find_by(granblue_id: granblue_id)

    if record
      record.update(game_raw_en: response_data)
      logger.debug "Updated #{model_name} #{granblue_id}"
    else
      logger.warn "#{model_name} with granblue_id #{granblue_id} not found in database"
    end
  rescue StandardError => e
    logger.error "Error updating #{model_name} #{granblue_id}: #{e.message}"
  end

  def process_all_records(model_name, only_missing: false)
    model = Object.const_get(model_name)
    scope = model
    scope = scope.where(game_raw_en: nil) if only_missing

    total = scope.count
    success_count = 0
    error_count = 0

    logger.info "Starting to fetch #{total} #{model_name.downcase}s#{' (missing data only)' if only_missing}..."

    scope.find_each do |record|
      logger.info "\nProcessing #{model_name} #{record.granblue_id} (#{success_count + error_count + 1}/#{total})"

      response = case model_name
                 when 'Character'
                   fetch_character(record.granblue_id)
                 when 'Weapon'
                   fetch_weapon(record.granblue_id)
                 when 'Summon'
                   fetch_summon(record.granblue_id)
                 end

      success_count += 1
      logger.debug "Successfully processed #{model_name} #{record.granblue_id}"

      sleep(1)
    rescue StandardError => e
      error_count += 1
      logger.error "Error processing #{model_name} #{record.granblue_id}: #{e.message}"
    end

    logger.info "\nProcessing complete!"
    logger.info "Total: #{total}"
    logger.info "Successful: #{success_count}"
    logger.info "Failed: #{error_count}"
  end

  class AuthenticationError < StandardError; end
end
